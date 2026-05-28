#!/usr/bin/env bash
# WorkLog++ — Main script
# Usage: wlog [COMMAND] [OPTIONS]
# See: wlog -h
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths (defaults; overridden by load_config)
# ---------------------------------------------------------------------------
WLOG_FILE="${WLOG_FILE:-${HOME}/.local/share/wlog/worklog.md}"
WLOG_THEME="${WLOG_THEME:-${HOME}/.config/wlog/theme.sh}"
WLOG_LAST_ENTRY="${HOME}/.local/share/wlog/.last_entry"
WLOG_HTML="${HOME}/.local/share/wlog/worklog.html"
WLOG_LOCK="/tmp/wlog_${USER}.lock"

# Script directory (for sourcing theme-default.sh at install time)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Color variables (populated by load_theme)
# ---------------------------------------------------------------------------
COLOR_TODAY=""
COLOR_YESTERDAY=""
COLOR_TOMORROW=""
COLOR_CHECKED=""
COLOR_UNCHECKED=""
COLOR_DATE_HEADING=""
COLOR_MONTH_HEADING=""
COLOR_RESET=""
COLOR_HIGHLIGHT=""
COLOR_BORDER=""

# ---------------------------------------------------------------------------
# Config loader (T006)
# ---------------------------------------------------------------------------
load_config() {
    local config_file="${HOME}/.config/wlog/config.sh"
    [[ -f "$config_file" ]] && source "$config_file"
    # Apply env overrides after sourcing (env takes precedence over config file)
    WLOG_FILE="${WLOG_FILE:-${HOME}/.local/share/wlog/worklog.md}"
    WLOG_THEME="${WLOG_THEME:-${HOME}/.config/wlog/theme.sh}"
    # First-run bootstrap (T039): create log file if missing
    if [[ ! -f "$WLOG_FILE" ]]; then
        mkdir -p "$(dirname "$WLOG_FILE")"
        local today_iso
        today_iso=$(date +%Y-%m-%d)
        local month_h
        month_h=$(month_heading "$today_iso")
        local today_log
        today_log=$(iso_to_log "$today_iso")
        printf "## %s\n\n### %s\n\n" "$month_h" "$today_log" > "$WLOG_FILE"
    fi
}

# ---------------------------------------------------------------------------
# Theme loader (T007)
# ---------------------------------------------------------------------------
load_theme() {
    # Load defaults from shipped theme
    local default_theme="${SCRIPT_DIR}/theme-default.sh"
    # When installed to ~/.local/bin, theme-default.sh won't be alongside it;
    # fall back to the installed user theme which was seeded from theme-default.sh
    if [[ -f "$default_theme" ]]; then
        # shellcheck source=/dev/null
        source "$default_theme"
    fi
    # Source user override if present
    if [[ -f "$WLOG_THEME" ]]; then
        # shellcheck source=/dev/null
        source "$WLOG_THEME"
    fi
    # Respect NO_COLOR
    if [[ -n "${NO_COLOR:-}" ]]; then
        COLOR_TODAY="" COLOR_YESTERDAY="" COLOR_TOMORROW=""
        COLOR_CHECKED="" COLOR_UNCHECKED="" COLOR_DATE_HEADING=""
        COLOR_MONTH_HEADING="" COLOR_RESET="" COLOR_HIGHLIGHT="" COLOR_BORDER=""
    fi
    # Suppress color when stdout is not a TTY
    if [[ ! -t 1 ]]; then
        COLOR_TODAY="" COLOR_YESTERDAY="" COLOR_TOMORROW=""
        COLOR_CHECKED="" COLOR_UNCHECKED="" COLOR_DATE_HEADING=""
        COLOR_MONTH_HEADING="" COLOR_RESET="" COLOR_HIGHLIGHT="" COLOR_BORDER=""
    fi
}

# ---------------------------------------------------------------------------
# Date helpers (T008)
# ---------------------------------------------------------------------------
log_to_iso() {
    # DD.MM.YYYY → YYYY-MM-DD
    local d="$1"
    echo "${d:6:4}-${d:3:2}-${d:0:2}"
}

iso_to_log() {
    # YYYY-MM-DD → DD.MM.YYYY
    local d="$1"
    echo "${d:8:2}.${d:5:2}.${d:0:4}"
}

month_heading() {
    # YYYY-MM-DD → "Month YYYY"  (e.g., "May 2026")
    date -d "$1" +"%B %Y"
}

# ---------------------------------------------------------------------------
# Workday resolver (T009)
# ---------------------------------------------------------------------------
resolve_workday() {
    local base_date="$1"  # YYYY-MM-DD
    local direction="$2"  # +1 or -1
    local offset_sign="+"
    [[ $direction -lt 0 ]] && offset_sign="-"
    local abs_dir="${direction#-}"

    local result_date
    result_date=$(date -d "${base_date} ${offset_sign}${abs_dir} days" +%Y-%m-%d)
    local dow
    dow=$(date -d "${result_date}" +%u)  # 1=Mon … 7=Sun

    if [[ $direction -gt 0 ]]; then
        [[ $dow -eq 6 ]] && result_date=$(date -d "${result_date} +2 days" +%Y-%m-%d)  # Sat→Mon
        [[ $dow -eq 7 ]] && result_date=$(date -d "${result_date} +1 day"  +%Y-%m-%d)  # Sun→Mon
    else
        [[ $dow -eq 7 ]] && result_date=$(date -d "${result_date} -2 days" +%Y-%m-%d)  # Sun→Fri
        [[ $dow -eq 6 ]] && result_date=$(date -d "${result_date} -1 day"  +%Y-%m-%d)  # Sat→Fri
    fi
    echo "$result_date"
}

# ---------------------------------------------------------------------------
# File I/O — parse day entries (T010)
# ---------------------------------------------------------------------------
parse_day_entries() {
    local date_log="$1"  # DD.MM.YYYY
    [[ ! -f "$WLOG_FILE" ]] && return 0
    awk -v target="### ${date_log}" '
        $0 == target       { found=1; next }
        found && /^### /   { exit }
        found && /^## /    { exit }
        found && /^- \[/   { print }
    ' "$WLOG_FILE"
}

# ---------------------------------------------------------------------------
# File I/O — ensure month + day section exists (T011)
# ---------------------------------------------------------------------------
ensure_day_section() {
    local date_log="$1"      # DD.MM.YYYY
    local date_iso
    date_iso=$(log_to_iso "$date_log")
    local month_h
    month_h=$(month_heading "$date_iso")
    local month_marker="## ${month_h}"
    local day_marker="### ${date_log}"

    (
        flock -w 5 9 || { echo "wlog: could not acquire log file lock (timeout 5s)" >&2; exit 2; }

        local tmpfile
        tmpfile=$(mktemp)

        if ! grep -qF "$day_marker" "$WLOG_FILE" 2>/dev/null; then
            if ! grep -qF "$month_marker" "$WLOG_FILE" 2>/dev/null; then
                # Need to add new month section
                # Find the right insertion point: after all existing content for earlier months
                # Simplest: append new month block at end of file
                # (entries are always appended chronologically)
                {
                    cat "$WLOG_FILE"
                    printf "\n--------------------\n## %s\n\n### %s\n\n" "$month_h" "$date_log"
                } > "$tmpfile"
            else
                # Month exists, add day heading after last entry in that month
                awk -v month="$month_marker" -v day="$day_marker" '
                    { lines[NR] = $0 }
                    END {
                        inserted = 0
                        for (i = 1; i <= NR; i++) {
                            print lines[i]
                            # Insert after month heading block, before next ## or EOF
                            if (!inserted && lines[i] == month) {
                                # scan forward to find insertion point
                                # (after last ### in this month, before next ## or EOF)
                                j = i + 1
                                last_day_line = i
                                while (j <= NR && lines[j] !~ /^## [^#]/) {
                                    if (lines[j] ~ /^### /) last_day_line = j
                                    j++
                                }
                                # We already printed up to i; need to print up to last_day_line
                                # then insert. Restart with awk reprocess is complex;
                                # use simpler approach: just append day at end of month block.
                            }
                        }
                    }
                ' "$WLOG_FILE" > /dev/null
                # Simpler: find last ### line in the month, insert new day after its entries
                awk -v month="$month_marker" -v day="$day_marker" '
                    BEGIN { in_month=0; buf=""; needs_newline=0 }
                    /^## / && $0 != month { in_month=0 }
                    $0 == month           { in_month=1 }
                    in_month && /^## / && $0 != month { in_month=0 }
                    {
                        if (in_month && /^## / && $0 != month) {
                            # Entering next month — insert our day before this line
                            printf "\n%s\n\n", day
                            in_month=0
                        }
                        print
                    }
                    END {
                        if (in_month) {
                            # Month was last section — append at end
                            printf "\n%s\n\n", day
                        }
                    }
                ' "$WLOG_FILE" > "$tmpfile"
            fi
            mv "$tmpfile" "$WLOG_FILE"
        else
            rm -f "$tmpfile"
        fi
    ) 9>"$WLOG_LOCK"
}

# ---------------------------------------------------------------------------
# File I/O — append entry (T012)
# ---------------------------------------------------------------------------
append_entry() {
    local date_log="$1"
    local text="$2"
    ensure_day_section "$date_log"
    local entry="- [ ] ${text}"
    local day_marker="### ${date_log}"

    (
        flock -w 5 9 || { echo "wlog: could not acquire log file lock (timeout 5s)" >&2; exit 2; }
        local tmpfile
        tmpfile=$(mktemp)
        awk -v marker="$day_marker" -v newentry="$entry" '
            { lines[NR] = $0 }
            END {
                i = 1
                while (i <= NR) {
                    print lines[i]
                    if (lines[i] == marker) {
                        # Skip forward past existing entries in this section
                        j = i + 1
                        while (j <= NR && (lines[j] ~ /^- \[/ || lines[j] == "")) {
                            print lines[j]
                            j++
                        }
                        # Insert new entry before next heading or blank-then-heading
                        print newentry
                        i = j
                        continue
                    }
                    i++
                }
            }
        ' "$WLOG_FILE" > "$tmpfile"
        mv "$tmpfile" "$WLOG_FILE"
    ) 9>"$WLOG_LOCK"

    # Save undo state
    mkdir -p "$(dirname "$WLOG_LAST_ENTRY")"
    printf '%s\n%s\n' "$date_log" "$entry" > "$WLOG_LAST_ENTRY"
}

# ---------------------------------------------------------------------------
# File I/O — toggle entry (T033)
# ---------------------------------------------------------------------------
toggle_entry() {
    local date_log="$1"
    local text="$2"  # full line e.g. "- [ ] some text" or "- [x] some text"
    local day_marker="### ${date_log}"

    (
        flock -w 5 9 || { echo "wlog: could not acquire log file lock (timeout 5s)" >&2; exit 2; }
        local tmpfile
        tmpfile=$(mktemp)
        awk -v marker="$day_marker" -v target="$text" '
            BEGIN { in_section=0; toggled=0 }
            $0 == marker { in_section=1; print; next }
            in_section && /^## / { in_section=0 }
            in_section && /^### / { in_section=0 }
            in_section && !toggled && $0 == target {
                toggled=1
                if (target ~ /^- \[ \]/) {
                    sub(/^- \[ \]/, "- [x]")
                } else {
                    sub(/^- \[x\]/, "- [ ]")
                }
            }
            { print }
        ' "$WLOG_FILE" > "$tmpfile"
        mv "$tmpfile" "$WLOG_FILE"
    ) 9>"$WLOG_LOCK"
}

# ---------------------------------------------------------------------------
# File I/O — remove entry (T034)
# ---------------------------------------------------------------------------
remove_entry() {
    local date_log="$1"
    local text="$2"  # full entry line to remove
    local day_marker="### ${date_log}"

    (
        flock -w 5 9 || { echo "wlog: could not acquire log file lock (timeout 5s)" >&2; exit 2; }
        local tmpfile
        tmpfile=$(mktemp)
        awk -v marker="$day_marker" -v target="$text" '
            BEGIN { in_section=0; removed=0 }
            $0 == marker { in_section=1; print; next }
            in_section && (/^## / || /^### /) { in_section=0 }
            in_section && !removed && $0 == target { removed=1; next }
            { print }
        ' "$WLOG_FILE" > "$tmpfile"
        mv "$tmpfile" "$WLOG_FILE"
    ) 9>"$WLOG_LOCK"
}

# ---------------------------------------------------------------------------
# Print a single day (T014)
# ---------------------------------------------------------------------------
print_day() {
    local date_log="$1"
    local color_heading="${2:-$COLOR_DATE_HEADING}"
    printf "%b### %s%b\n" "$color_heading" "$date_log" "$COLOR_RESET"
    local entries
    entries=$(parse_day_entries "$date_log")
    if [[ -z "$entries" ]]; then
        printf "  %b(no entries)%b\n" "$COLOR_BORDER" "$COLOR_RESET"
    else
        while IFS= read -r line; do
            if [[ "$line" == "- [x]"* || "$line" == "- [X]"* ]]; then
                printf "  %b%s%b\n" "$COLOR_CHECKED" "$line" "$COLOR_RESET"
            else
                printf "  %b%s%b\n" "$COLOR_UNCHECKED" "$line" "$COLOR_RESET"
            fi
        done <<< "$entries"
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# TUI: add entry prompt (T024)
# ---------------------------------------------------------------------------
tui_add_entry() {
    local date_log="$1"
    printf "Add activity for %b%s%b (Enter to save, Ctrl+C to cancel):\n" \
        "$COLOR_DATE_HEADING" "$date_log" "$COLOR_RESET"
    # Trap Ctrl+C
    trap 'printf "\nCancelled.\n" >&2; exit 130' INT
    local text=""
    while true; do
        IFS= read -e -r -p "> " text || { printf "\nCancelled.\n" >&2; exit 130; }
        if [[ -n "$text" ]]; then
            break
        fi
        printf "  (empty — please enter a description)\n"
    done
    trap - INT
    append_entry "$date_log" "$text"
    printf "Saved: [%s] %b- [ ] %s%b\n" "$date_log" "$COLOR_UNCHECKED" "$text" "$COLOR_RESET"
}

# ---------------------------------------------------------------------------
# CMD: undo (T027)
# ---------------------------------------------------------------------------
cmd_undo() {
    if [[ ! -f "$WLOG_LAST_ENTRY" ]] || [[ ! -s "$WLOG_LAST_ENTRY" ]]; then
        echo "Nothing to undo."
        exit 0
    fi
    local date_log entry_text
    date_log=$(sed -n '1p' "$WLOG_LAST_ENTRY")
    entry_text=$(sed -n '2p' "$WLOG_LAST_ENTRY")
    if [[ -z "$date_log" ]] || [[ -z "$entry_text" ]]; then
        echo "Nothing to undo."
        exit 0
    fi
    remove_entry "$date_log" "$entry_text"
    > "$WLOG_LAST_ENTRY"
    printf "Removed: [%s] %s\n" "$date_log" "$entry_text"
}

# ---------------------------------------------------------------------------
# CMD: md → HTML (T036)
# ---------------------------------------------------------------------------
md_to_html() {
    mkdir -p "$(dirname "$WLOG_HTML")"
    awk '
    BEGIN {
        print "<!DOCTYPE html><html><head><meta charset=\"utf-8\">"
        print "<title>WorkLog++</title>"
        print "<style>"
        print "  body{font-family:system-ui,sans-serif;max-width:860px;margin:2rem auto;padding:0 1rem;color:#333;}"
        print "  h2{color:#2c3e50;border-bottom:2px solid #eee;padding-bottom:.3rem;margin-top:2rem;}"
        print "  h3{color:#34495e;margin-top:1.2rem;}"
        print "  ul{list-style:none;padding:0;}"
        print "  li{padding:.2rem 0;}"
        print "  li.done{color:#27ae60;text-decoration:line-through;opacity:.8;}"
        print "  li.todo{color:#e67e22;}"
        print "  hr{border:none;border-top:1px solid #ddd;margin:1.5rem 0;}"
        print "</style></head><body>"
        in_list = 0
    }
    /^## /  { close_list(); printf "<h2>%s</h2>\n", substr($0,4); next }
    /^### / { close_list(); printf "<h3>%s</h3>\n", substr($0,5); next }
    /^-+$/ { close_list(); print "<hr>"; next }
    /^- \[x\]/ || /^- \[X\]/ {
        open_list()
        line = substr($0, 7)
        gsub(/&/, "\\&amp;", line); gsub(/</, "\\&lt;", line); gsub(/>/, "\\&gt;", line)
        printf "<li class=\"done\">&#9745; %s</li>\n", line
        next
    }
    /^- \[ \]/ {
        open_list()
        line = substr($0, 7)
        gsub(/&/, "\\&amp;", line); gsub(/</, "\\&lt;", line); gsub(/>/, "\\&gt;", line)
        printf "<li class=\"todo\">&#9744; %s</li>\n", line
        next
    }
    /^$/ { close_list(); next }
    function open_list()  { if (!in_list) { print "<ul>"; in_list=1 } }
    function close_list() { if (in_list)  { print "</ul>"; in_list=0 } }
    END { close_list(); print "</body></html>" }
    ' "$WLOG_FILE" > "$WLOG_HTML"
}

# ---------------------------------------------------------------------------
# CMD: open browser (T037)
# ---------------------------------------------------------------------------
open_browser() {
    local file="$1"
    if uname -r 2>/dev/null | grep -qiE 'microsoft|WSL'; then
        local win_path
        win_path=$(wslpath -w "$file" 2>/dev/null) || win_path="$file"
        powershell.exe -Command "Start-Process '$win_path'" &>/dev/null || true
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$file" &>/dev/null &
    elif command -v open &>/dev/null; then
        open "$file" &>/dev/null &
    else
        printf "wlog: could not detect a browser opener. File at: %s\n" "$file" >&2
    fi
}

# ---------------------------------------------------------------------------
# Validate positive integer argument
# ---------------------------------------------------------------------------
validate_n() {
    local flag="$1" val="$2"
    if [[ -z "${val:-}" ]] || ! [[ "$val" =~ ^[1-9][0-9]*$ ]]; then
        printf "wlog: invalid argument for %s: must be a positive integer\n" "$flag" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Help text (T017)
# ---------------------------------------------------------------------------
cmd_help() {
cat <<'EOF'
Usage: wlog [COMMAND] [OPTIONS]

  wlog              Show today's and yesterday's activities
  wlog -y           Show yesterday's activities
  wlog -t           Show tomorrow's activities
  wlog -p N         Show activities N days ago (calendar)
  wlog -f N         Show activities N days ahead (calendar)
  wlog +            Add an activity for today (interactive)
  wlog + -y/-t      Add an activity for yesterday/tomorrow
  wlog + -p/-f N    Add an activity for N days ago/ahead
  wlog -c           Open calendar TUI view
  wlog -a           Open full log as HTML in browser
  wlog --undo       Remove last added entry
  wlog -h           Show this help

Config:
  WLOG_FILE         Override log file path (default: ~/.local/share/wlog/worklog.md)
  WLOG_THEME        Override theme file path (default: ~/.config/wlog/theme.sh)
  NO_COLOR          Set to any value to disable color output
  ~/.config/wlog/theme.sh    Color theme overrides (sourced shell variables)
  ~/.config/wlog/config.sh   Config overrides (WLOG_FILE=, WLOG_THEME=)
EOF
}

# ---------------------------------------------------------------------------
# Main (T015, T016, T019–T022, T025, T035, T038)
# ---------------------------------------------------------------------------
main() {
    load_config
    load_theme

    local today_iso
    today_iso=$(date +%Y-%m-%d)
    local today_log
    today_log=$(iso_to_log "$today_iso")

    local cmd="${1:-}"

    case "$cmd" in
        "")
            # Default: show yesterday + today
            local yesterday_iso
            yesterday_iso=$(resolve_workday "$today_iso" -1)
            local yesterday_log
            yesterday_log=$(iso_to_log "$yesterday_iso")
            print_day "$yesterday_log" "$COLOR_YESTERDAY"
            print_day "$today_log" "$COLOR_TODAY"
            ;;

        "-y")
            local d_iso
            d_iso=$(resolve_workday "$today_iso" -1)
            print_day "$(iso_to_log "$d_iso")" "$COLOR_YESTERDAY"
            ;;

        "-t")
            local d_iso
            d_iso=$(resolve_workday "$today_iso" +1)
            print_day "$(iso_to_log "$d_iso")" "$COLOR_TOMORROW"
            ;;

        "-p")
            validate_n "-p" "${2:-}"
            local n="$2"
            local d_iso
            d_iso=$(date -d "${today_iso} -${n} days" +%Y-%m-%d)
            print_day "$(iso_to_log "$d_iso")"
            ;;

        "-f")
            validate_n "-f" "${2:-}"
            local n="$2"
            local d_iso
            d_iso=$(date -d "${today_iso} +${n} days" +%Y-%m-%d)
            print_day "$(iso_to_log "$d_iso")"
            ;;

        "+")
            # Add entry — parse optional date flag
            local target_log="$today_log"
            local flag="${2:-}"
            case "$flag" in
                "-y")
                    target_log=$(iso_to_log "$(resolve_workday "$today_iso" -1)")
                    ;;
                "-t")
                    target_log=$(iso_to_log "$(resolve_workday "$today_iso" +1)")
                    ;;
                "-p")
                    validate_n "-p" "${3:-}"
                    target_log=$(iso_to_log "$(date -d "${today_iso} -${3} days" +%Y-%m-%d)")
                    ;;
                "-f")
                    validate_n "-f" "${3:-}"
                    target_log=$(iso_to_log "$(date -d "${today_iso} +${3} days" +%Y-%m-%d)")
                    ;;
                "")
                    ;;
                *)
                    printf "wlog: unknown flag '%s'. See: wlog -h\n" "$flag" >&2
                    exit 1
                    ;;
            esac
            tui_add_entry "$target_log"
            ;;

        "-c")
            # Source and launch TUI
            local tui_script
            # When installed, wlog-tui.sh is at ~/.local/bin/wlog-tui
            # When run from src/, it's alongside wlog.sh
            if [[ -f "${SCRIPT_DIR}/wlog-tui.sh" ]]; then
                tui_script="${SCRIPT_DIR}/wlog-tui.sh"
            elif [[ -f "${HOME}/.local/bin/wlog-tui" ]]; then
                tui_script="${HOME}/.local/bin/wlog-tui"
            else
                printf "wlog: wlog-tui not found. Re-run install.sh\n" >&2
                exit 2
            fi
            # shellcheck source=/dev/null
            source "$tui_script"
            tui_calendar "$today_iso"
            ;;

        "-a")
            md_to_html
            printf "Generated: %s\n" "$WLOG_HTML"
            open_browser "$WLOG_HTML"
            ;;

        "--undo")
            cmd_undo
            ;;

        "-h"|"--help")
            cmd_help
            ;;

        *)
            printf "wlog: unknown command '%s'. See: wlog -h\n" "$cmd" >&2
            exit 1
            ;;
    esac
}

main "$@"
