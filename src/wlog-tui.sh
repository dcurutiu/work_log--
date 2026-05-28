#!/usr/bin/env bash
# WorkLog++ TUI Calendar View
# Sourced by wlog.sh when `wlog -c` is invoked.
# Requires: tput, stty, read  (all standard)
# Functions in this file call toggle_entry / remove_entry / append_entry
# which are defined in wlog.sh (already sourced before this file).

# ---------------------------------------------------------------------------
# T029 — terminal enter/exit
# ---------------------------------------------------------------------------
_TUI_STTY_SAVE=""

tui_enter() {
    _TUI_STTY_SAVE=$(stty -g)
    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true
    stty raw -echo 2>/dev/null || true
}

tui_exit() {
    stty "$_TUI_STTY_SAVE" 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# T030 — read a single keypress; return a named token
# ---------------------------------------------------------------------------
read_key() {
    # Use -N1 (uppercase) instead of -n1: -n1 honors the default delimiter
    # (newline), so when the user presses Enter, bash consumes the \n and
    # leaves the variable EMPTY — making Enter silently undetectable.
    # -N1 reads exactly 1 byte ignoring any delimiter.
    local ch esc seq
    IFS= read -rsN1 ch
    if [[ "$ch" == $'\x1b' ]]; then
        # Generous timeout (0.3s) to handle slow terminals (VS Code, SSH, etc.)
        IFS= read -rsN1 -t 0.3 esc 2>/dev/null || esc=""
        # Handle both CSI (\x1b[) and SS3 (\x1bO) arrow key encodings
        if [[ "$esc" == "[" || "$esc" == "O" ]]; then
            IFS= read -rsN1 -t 0.3 seq 2>/dev/null || seq=""
            case "$seq" in
                A) echo "UP"    ; return ;;
                B) echo "DOWN"  ; return ;;
                C) echo "RIGHT" ; return ;;
                D) echo "LEFT"  ; return ;;
            esac
        fi
        # Unknown escape sequence — drain any leftover bytes so they don't
        # get mis-read as the next keypress, then treat as ESC
        while IFS= read -rsN1 -t 0.05 _drain 2>/dev/null; do :; done
        echo "ESC"
        return
    fi
    case "$ch" in
        $'\n'|$'\r') echo "ENTER"  ;;
        $'\t')        echo "TAB"    ;;
        d)            echo "d"      ;;
        n)            echo "n"      ;;
        '[')          echo "["      ;;
        ']')          echo "]"      ;;
        q|Q)          echo "q"      ;;
        *)            echo "$ch"    ;;
    esac
}

# ---------------------------------------------------------------------------
# T031 — render the three-column calendar
# ---------------------------------------------------------------------------
# Globals set by tui_calendar before calling this:
#   _TUI_COL_DATES   — array of 3 DD.MM.YYYY dates  (left / center / right)
#   _TUI_FOCUSED_COL — 0..2
#   _TUI_CURSOR_ROW  — 0-based index within focused column's entry list
#   _TUI_ENTRIES_*   — arrays set per column
#   COLS / LINES     — terminal dimensions
render_calendar() {
    local term_cols term_lines
    term_cols=$(tput cols  2>/dev/null || echo 80)
    term_lines=$(tput lines 2>/dev/null || echo 24)

    tput clear 2>/dev/null || printf '\033[2J\033[H'

    local col_w=$(( (term_cols - 4) / 3 )) || true
    [[ $col_w -lt 20 ]] && col_w=20

    local col_labels=("Yesterday" "Today" "Tomorrow")
    local col_colors=("$COLOR_YESTERDAY" "$COLOR_TODAY" "$COLOR_TOMORROW")

    # Header row
    tput cup 0 0 2>/dev/null
    local c
    for c in 0 1 2; do
        local date_str="${_TUI_COL_DATES[$c]}"
        local label="${col_labels[$c]}"
        local color="${col_colors[$c]}"
        local col_x=$(( c * (col_w + 2) ))
        tput cup 0 $col_x 2>/dev/null
        printf "%b%-${col_w}s%b" "$color" "${label}: ${date_str}" "$COLOR_RESET"
    done

    # Separator line
    tput cup 1 0 2>/dev/null
    printf "%b%s%b" "$COLOR_BORDER" "$(printf '%*s' "$term_cols" | tr ' ' '-')" "$COLOR_RESET"

    # Entry rows
    local max_rows=$(( term_lines - 5 ))
    [[ $max_rows -lt 1 ]] && max_rows=1
    local text_w=$(( col_w - 3 )) || true  # usable text width (cursor=2, space=1)
    [[ $text_w -lt 5 ]] && text_w=5

    for c in 0 1 2; do
        local col_x=$(( c * (col_w + 2) ))
        local entries_ref="_TUI_ENTRIES_${c}[@]"
        local entries=("${!entries_ref}")
        local nentries=${#entries[@]}

        # Build word-wrapped display lines for this column.
        # Each element: "entry_idx|is_first|text"
        local display_lines=()
        local ei
        for (( ei=0; ei<nentries; ei++ )); do
            local remaining="${entries[$ei]}"
            local is_first=1
            while [[ ${#remaining} -gt $text_w ]]; do
                local chunk="${remaining:0:$text_w}"
                local bp=$text_w
                # Try to break at last space within the width
                local i
                for (( i=text_w-1; i>0; i-- )); do
                    if [[ "${chunk:$i:1}" == " " ]]; then
                        bp=$i; break
                    fi
                done
                if [[ $bp -eq $text_w ]]; then
                    display_lines+=("${ei}|${is_first}|${remaining:0:$text_w}")
                    remaining="${remaining:$text_w}"
                else
                    display_lines+=("${ei}|${is_first}|${remaining:0:$bp}")
                    remaining="${remaining:$(( bp + 1 ))}"
                fi
                is_first=0
            done
            display_lines+=("${ei}|${is_first}|${remaining}")
        done

        local total_display=${#display_lines[@]}
        local row
        for (( row=0; row<max_rows; row++ )); do
            tput cup $(( row + 2 )) $col_x 2>/dev/null
            printf "%-${col_w}s" ""          # clear cell
            tput cup $(( row + 2 )) $col_x 2>/dev/null
            if (( row < total_display )); then
                local dline="${display_lines[$row]}"
                local d_ei="${dline%%|*}"; local rest="${dline#*|}"
                local d_first="${rest%%|*}"; local d_text="${rest#*|}"
                local entry_color="$COLOR_UNCHECKED"
                if [[ "${entries[$d_ei]}" == "- [x]"* || "${entries[$d_ei]}" == "- [X]"* ]]; then
                    entry_color="$COLOR_CHECKED"
                fi
                if [[ $c -eq $_TUI_FOCUSED_COL && $d_ei -eq $_TUI_CURSOR_ROW && $d_first -eq 1 ]]; then
                    # First line of selected entry — show cursor
                    printf "%b►%b %b%-${text_w}s%b" \
                        "$COLOR_HIGHLIGHT" "$COLOR_RESET" \
                        "$entry_color" "$d_text" "$COLOR_RESET"
                elif [[ $c -eq $_TUI_FOCUSED_COL && $d_ei -eq $_TUI_CURSOR_ROW ]]; then
                    # Continuation line of selected entry — indent to match cursor width
                    printf "   %b%-$(( text_w - 1 ))s%b" "$entry_color" "$d_text" "$COLOR_RESET"
                else
                    printf "  %b%-${text_w}s%b" "$entry_color" "$d_text" "$COLOR_RESET"
                fi
            elif (( row == 0 && nentries == 0 )); then
                # Empty column
                if [[ $c -eq $_TUI_FOCUSED_COL ]]; then
                    printf "%b►%b %b%-${text_w}s%b" \
                        "$COLOR_HIGHLIGHT" "$COLOR_RESET" \
                        "$COLOR_BORDER" "(no entries)" "$COLOR_RESET"
                else
                    printf "  %b%-${text_w}s%b" "$COLOR_BORDER" "(no entries)" "$COLOR_RESET"
                fi
            fi
        done
    done

    # Status bar at bottom
    local status_row=$(( term_lines - 2 ))
    tput cup $status_row 0 2>/dev/null
    printf "%b%s%b" "$COLOR_BORDER" \
        "$(printf '%*s' "$term_cols" | tr ' ' '-')" "$COLOR_RESET"
    tput cup $(( status_row + 1 )) 0 2>/dev/null
    printf "%b↑↓%b move  %bEnter%b toggle  %bd+y%b delete  %bn%b add  %b[/]%b shift day  %bTab%b switch col  %bq%b quit" \
        "$COLOR_HIGHLIGHT" "$COLOR_RESET" \
        "$COLOR_HIGHLIGHT" "$COLOR_RESET" \
        "$COLOR_HIGHLIGHT" "$COLOR_RESET" \
        "$COLOR_HIGHLIGHT" "$COLOR_RESET" \
        "$COLOR_HIGHLIGHT" "$COLOR_RESET" \
        "$COLOR_HIGHLIGHT" "$COLOR_RESET" \
        "$COLOR_HIGHLIGHT" "$COLOR_RESET"
}

# ---------------------------------------------------------------------------
# Helper: load entries for a column into _TUI_ENTRIES_N array
# ---------------------------------------------------------------------------
_tui_load_entries() {
    local col="$1"
    local date_log="${_TUI_COL_DATES[$col]}"
    local raw
    raw=$(parse_day_entries "$date_log" 2>/dev/null || true)
    # Read into per-column array using nameref-style eval (bash 4 compat)
    eval "_TUI_ENTRIES_${col}=()"
    if [[ -n "$raw" ]]; then
        while IFS= read -r line; do
            eval "_TUI_ENTRIES_${col}+=(\"\$line\")"
        done <<< "$raw"
    fi
}

# ---------------------------------------------------------------------------
# Helper: clamp cursor to valid range for current column
# ---------------------------------------------------------------------------
_tui_clamp_cursor() {
    local ref="_TUI_ENTRIES_${_TUI_FOCUSED_COL}[@]"
    local entries=("${!ref}")
    local nentries=${#entries[@]}
    if [[ $nentries -eq 0 ]]; then _TUI_CURSOR_ROW=0; return; fi
    [[ $_TUI_CURSOR_ROW -lt 0 ]] && _TUI_CURSOR_ROW=0
    [[ $_TUI_CURSOR_ROW -ge $nentries ]] && _TUI_CURSOR_ROW=$(( nentries - 1 )) || true
}

# ---------------------------------------------------------------------------
# Helper: inline add prompt (used in TUI for 'n' key)
# ---------------------------------------------------------------------------
_tui_inline_add() {
    local date_log="${_TUI_COL_DATES[$_TUI_FOCUSED_COL]}"
    local term_lines
    term_lines=$(tput lines 2>/dev/null || echo 24)
    local prompt_row=$(( term_lines - 4 ))

    # Restore normal terminal mode (echo on, cooked) and show cursor
    stty "$_TUI_STTY_SAVE" 2>/dev/null || true
    tput cnorm 2>/dev/null || true

    tput cup $prompt_row 0 2>/dev/null
    tput el 2>/dev/null || true
    printf "%b  Add for %s (Enter=save, Ctrl+C=cancel):%b " \
        "$COLOR_HIGHLIGHT" "$date_log" "$COLOR_RESET"

    local text=""
    IFS= read -r text 2>/dev/null || text=""

    # Re-enter raw mode and re-hide cursor
    stty raw -echo 2>/dev/null || true
    tput civis 2>/dev/null || true

    if [[ -n "$text" ]]; then
        append_entry "$date_log" "$text"
    fi
}

# ---------------------------------------------------------------------------
# T032 — main TUI event loop
# ---------------------------------------------------------------------------
tui_calendar() {
    local center_date="${1:-$(date +%Y-%m-%d)}"

    # Compute left / center / right dates (workday-aware)
    local left_date right_date
    left_date=$(resolve_workday "$center_date" -1)
    right_date=$(resolve_workday "$center_date" +1)

    _TUI_COL_DATES=( "$(iso_to_log "$left_date")" "$(iso_to_log "$center_date")" "$(iso_to_log "$right_date")" )
    _TUI_FOCUSED_COL=1   # start on today (center)
    _TUI_CURSOR_ROW=0

    # Load all column entries
    _TUI_ENTRIES_0=()
    _TUI_ENTRIES_1=()
    _TUI_ENTRIES_2=()
    _tui_load_entries 0
    _tui_load_entries 1
    _tui_load_entries 2

    tui_enter
    trap 'tui_exit; exit 0' EXIT INT TERM

    local pending_d=0  # tracks whether 'd' was pressed waiting for 'y' confirm

    while true; do
        render_calendar

        local key
        key=$(read_key)

        case "$key" in
            UP)
                _TUI_CURSOR_ROW=$(( _TUI_CURSOR_ROW - 1 )) || true
                _tui_clamp_cursor
                ;;

            DOWN)
                _TUI_CURSOR_ROW=$(( _TUI_CURSOR_ROW + 1 )) || true
                _tui_clamp_cursor
                ;;

            LEFT)
                _TUI_FOCUSED_COL=$(( (_TUI_FOCUSED_COL - 1 + 3) % 3 )) || true
                _tui_clamp_cursor
                pending_d=0
                ;;

            RIGHT|TAB)
                _TUI_FOCUSED_COL=$(( (_TUI_FOCUSED_COL + 1) % 3 )) || true
                _tui_clamp_cursor
                pending_d=0
                ;;

            ENTER)
                pending_d=0
                local ref="_TUI_ENTRIES_${_TUI_FOCUSED_COL}[@]"
                local entries=("${!ref}")
                local nentries=${#entries[@]}
                if [[ $nentries -gt 0 && $_TUI_CURSOR_ROW -lt $nentries ]]; then
                    local entry="${entries[$_TUI_CURSOR_ROW]}"
                    local date_log="${_TUI_COL_DATES[$_TUI_FOCUSED_COL]}"
                    toggle_entry "$date_log" "$entry" || true
                    _tui_load_entries "$_TUI_FOCUSED_COL"
                fi
                ;;

            d)
                pending_d=1
                ;;

            n)
                pending_d=0
                _tui_inline_add || true
                _tui_load_entries "$_TUI_FOCUSED_COL"
                _tui_clamp_cursor
                ;;

            y)
                if [[ $pending_d -eq 1 ]]; then
                    pending_d=0
                    local ref="_TUI_ENTRIES_${_TUI_FOCUSED_COL}[@]"
                    local entries=("${!ref}")
                    local nentries=${#entries[@]}
                    if [[ $nentries -gt 0 && $_TUI_CURSOR_ROW -lt $nentries ]]; then
                        local entry="${entries[$_TUI_CURSOR_ROW]}"
                        local date_log="${_TUI_COL_DATES[$_TUI_FOCUSED_COL]}"
                        remove_entry "$date_log" "$entry" || true
                        _tui_load_entries "$_TUI_FOCUSED_COL"
                        _tui_clamp_cursor
                    fi
                fi
                ;;

            '[')
                pending_d=0
                # Shift all dates one workday backward
                local new_center_iso
                new_center_iso=$(log_to_iso "${_TUI_COL_DATES[1]}")
                new_center_iso=$(resolve_workday "$new_center_iso" -1)
                local new_left_iso new_right_iso
                new_left_iso=$(resolve_workday "$new_center_iso" -1)
                new_right_iso=$(resolve_workday "$new_center_iso" +1)
                _TUI_COL_DATES=( "$(iso_to_log "$new_left_iso")" "$(iso_to_log "$new_center_iso")" "$(iso_to_log "$new_right_iso")" )
                _tui_load_entries 0
                _tui_load_entries 1
                _tui_load_entries 2
                _tui_clamp_cursor
                ;;

            ']')
                pending_d=0
                # Shift all dates one workday forward
                local new_center_iso
                new_center_iso=$(log_to_iso "${_TUI_COL_DATES[1]}")
                new_center_iso=$(resolve_workday "$new_center_iso" +1)
                local new_left_iso new_right_iso
                new_left_iso=$(resolve_workday "$new_center_iso" -1)
                new_right_iso=$(resolve_workday "$new_center_iso" +1)
                _TUI_COL_DATES=( "$(iso_to_log "$new_left_iso")" "$(iso_to_log "$new_center_iso")" "$(iso_to_log "$new_right_iso")" )
                _tui_load_entries 0
                _tui_load_entries 1
                _tui_load_entries 2
                _tui_clamp_cursor
                ;;

            q|Q|ESC)
                break
                ;;

            *)
                pending_d=0
                ;;
        esac
    done

    tui_exit
    trap - EXIT INT TERM
}
