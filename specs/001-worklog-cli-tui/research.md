# Research: WorkLog++ CLI & TUI Activity Logger

**Phase**: 0 — Pre-design  
**Date**: 2026-05-28  
**Branch**: `001-worklog-cli-tui`

---

## R-001: Fish Shell + Bash Script Compatibility

**Decision**: Write `wlog` as a `#!/usr/bin/env bash` script. Install to `~/.local/bin/wlog`. Fish users add this directory to PATH via `fish_add_path ~/.local/bin` (or `set -gx PATH ~/.local/bin $PATH` in `config.fish`). No fish-specific syntax needed anywhere in the project.

**Rationale**: The OS kernel handles shebang execution — when fish runs `wlog`, it forks a process and the kernel reads the shebang line, executing bash as the interpreter. Fish never sees the script body. Environment variables (`$HOME`, `$PATH`, `WLOG_FILE`, etc.) are inherited by the subprocess correctly. The script does not need to be sourced, only invoked.

**Alternatives Considered**:
- Write in fish syntax: rejected — bash users would be excluded; `source` semantics differ
- Wrapper script per shell: rejected — unnecessary complexity; shebang is sufficient

**Fish PATH setup** (goes in install.sh output instructions):
```fish
fish_add_path ~/.local/bin
```

**Gotchas**:
- Never `source wlog.sh` from fish — it would try to parse bash syntax as fish
- `stty` calls in the script affect the terminal that fish is running; cleanup via `trap 'stty "$stty_orig"' EXIT` is mandatory

---

## R-002: GNU date Weekend Skip Logic

**Decision**: Implement `resolve_workday()` bash function using `date -d` arithmetic and `date +%u` for day-of-week checking. Apply only to named shortcuts (`-y`, `-t`) and default view. Raw offsets (`-p N`, `-f N`) remain calendar-based without weekend skipping.

**Rationale**: The user's requirement is work-context aware: "yesterday" means "last workday" and "tomorrow" means "next workday". This only applies to shorthand aliases, not explicit numeric offsets (where the user knows exactly what day they want).

**Algorithm**:
```bash
# Returns workday-adjusted date for named shortcuts.
# direction: +1 = "tomorrow", -1 = "yesterday"
# Only adjusts if the result lands on a weekend.
resolve_workday() {
    local base_date="$1"   # YYYY-MM-DD
    local direction="$2"   # +1 or -1 only (for named shortcuts)
    local offset_sign="+"
    [[ $direction -lt 0 ]] && offset_sign="-"
    local abs_dir=${direction#-}

    local result_date
    result_date=$(date -d "${base_date} ${offset_sign}${abs_dir} days" +%Y-%m-%d)
    local dow
    dow=$(date -d "${result_date}" +%u)   # 1=Mon ... 7=Sun

    if [[ $direction -gt 0 ]]; then       # forward (tomorrow)
        [[ $dow -eq 6 ]] && result_date=$(date -d "${result_date} +2 days" +%Y-%m-%d)  # Sat → Mon
        [[ $dow -eq 7 ]] && result_date=$(date -d "${result_date} +1 day"  +%Y-%m-%d)  # Sun → Mon
    else                                   # backward (yesterday)
        [[ $dow -eq 7 ]] && result_date=$(date -d "${result_date} -2 days" +%Y-%m-%d)  # Sun → Fri
        [[ $dow -eq 6 ]] && result_date=$(date -d "${result_date} -1 day"  +%Y-%m-%d)  # Sat → Fri
    fi
    echo "$result_date"
}
```

**Coverage matrix**:

| Today    | `-y` result (direction=-1) | `-t` result (direction=+1) |
| -------- | -------------------------- | -------------------------- |
| Monday   | Friday (skips Sun)         | Tuesday                    |
| Friday   | Thursday                   | Monday (skips Sat)         |
| Saturday | Friday                     | Monday                     |
| Sunday   | Friday                     | Monday                     |

**Alternatives Considered**:
- Apply weekend skip to all offsets: rejected — `wlog -p 2` should mean exactly 2 calendar days ago
- Epoch arithmetic: rejected — harder to read; GNU date handles month overflow natively

---

## R-003: Bash tput TUI Keyboard Navigation

**Decision**: Use `stty raw -echo` + `read -rsn1` for single-keypress capture. Parse escape sequences for arrow keys. Use `tput clear`, `tput cup ROW COL`, `tput smso`/`tput rmso` for rendering. Restore terminal state via `trap 'stty "$stty_orig"' EXIT INT TERM`.

**Rationale**: `stty raw` disables terminal line-buffering, allowing single-keypress reads without Enter. `read -rsn1` reads one byte; arrow keys send 3-byte escape sequences (`ESC [ A/B/C/D`) which require a second read of 2 bytes after detecting `ESC`. `tput cup` is portable across terminal emulators that support `ncurses`.

**Key read pattern**:
```bash
read_key() {
    local key
    IFS= read -rsn1 key
    if [[ $key == $'\x1b' ]]; then
        local seq
        IFS= read -rsn2 -t 0.1 seq    # timeout prevents blocking on lone ESC
        case "$seq" in
            '[A') echo "UP"    ;;
            '[B') echo "DOWN"  ;;
            '[C') echo "RIGHT" ;;
            '[D') echo "LEFT"  ;;
            *)    echo "ESC"   ;;
        esac
    else
        echo "$key"
    fi
}
```

**Terminal setup/teardown pattern**:
```bash
_stty_orig=""
tui_enter() {
    _stty_orig=$(stty -g)
    stty raw -echo
    tput smcup     # switch to alternate screen
    tput civis     # hide cursor
}

tui_exit() {
    tput cnorm     # show cursor
    tput rmcup     # restore main screen
    stty "$_stty_orig"
}

trap 'tui_exit' EXIT INT TERM
```

**Escape sequences** (ANSI/VT100, standard across xterm, gnome-terminal, WSL console):
```
Up:    \x1b[A
Down:  \x1b[B
Right: \x1b[C
Left:  \x1b[D
Enter: \r  (carriage return in raw mode)
Tab:   \t
ESC:   \x1b  (with 0.1s timeout on seq read)
```

**Alternatives Considered**:
- `dialog` utility: provides ready-made TUI widgets but is an external dependency
- Python `curses`: cleaner API but requires python3 — violates Shell-First principle
- `whiptail`/`zenity`: rejected for same reason

---

## R-004: awk Markdown-to-HTML Converter

**Decision**: Embed an `awk` program in `wlog.sh` that converts only the log file constructs: `## X` → `<h2>`, `### X` → `<h3>`, `- [x] text` → checked checkbox `<li>`, `- [ ] text` → unchecked `<li>`, `---` → `<hr>`, blank lines → `</ul>` paragraph boundaries. Wrap output in a minimal self-contained HTML skeleton with inline CSS for readability.

**Rationale**: The log file uses only 5 Markdown constructs. A 20-line `awk` script covers all of them without any external tool. The generated HTML is ephemeral and lives at `~/.local/share/wlog/worklog.html`; it is regenerated on every `wlog -a` call.

**awk skeleton**:
```awk
BEGIN {
    print "<html><head><meta charset='utf-8'>"
    print "<style>body{font-family:sans-serif;max-width:800px;margin:2rem auto;}"
    print "h2{color:#2c3e50;border-bottom:2px solid #eee;} h3{color:#34495e;}"
    print ".done{color:#27ae60;text-decoration:line-through;} ul{list-style:none;padding:0;}"
    print "</style></head><body>"
    in_list = 0
}
/^## /   { close_list(); printf "<h2>%s</h2>\n", substr($0,4); next }
/^### /  { close_list(); printf "<h3>%s</h3>\n", substr($0,5); next }
/^---/   { close_list(); print "<hr>"; next }
/^- \[x\]/ { open_list(); sub(/^- \[x\] /,""); printf "<li class='done'>&#9745; %s</li>\n",$0; next }
/^- \[ \]/ { open_list(); sub(/^- \[ \] /,""); printf "<li>&#9744; %s</li>\n",$0; next }
/^$/     { close_list(); next }
END      { close_list(); print "</body></html>" }
function open_list()  { if (!in_list) { print "<ul>"; in_list=1 } }
function close_list() { if (in_list)  { print "</ul>"; in_list=0 } }
```

---

## R-005: WSL Browser Launch Detection

**Decision**: Detect WSL by checking `uname -r` for the string `microsoft` (case-insensitive). If WSL: use `powershell.exe -Command "Start-Process '$(wslpath -w "$html_file")'"`. Fallback chain: `wslview` (from `wslu` if installed) → `xdg-open` (if configured) → `powershell.exe`. On native Linux: use `xdg-open`.

**Rationale**: `powershell.exe` is always available on WSL2 via `/mnt/c/Windows/System32/WindowsPowerShell/v1/powershell.exe`; it does not need to be on PATH. `wslpath -w` converts the Linux path to a Windows path. This avoids requiring the `wslu` package.

```bash
open_browser() {
    local file="$1"
    if uname -r | grep -qi microsoft; then
        local win_path
        win_path=$(wslpath -w "$file")
        powershell.exe -Command "Start-Process '$win_path'" &>/dev/null
    else
        xdg-open "$file" &>/dev/null || open "$file" &>/dev/null
    fi
}
```

---

## R-006: File Write Locking + undo State

**Decision**: Use `flock 9` with a lockfile at `/tmp/wlog_${USER}.lock` for all write operations. Undo state stored in `~/.local/share/wlog/.last_entry` as two lines: line 1 = ISO date (`YYYY-MM-DD`), line 2 = the full `- [ ] text` entry. `--undo` reads this file, removes the matching line from `worklog.md` (first matching occurrence on that date), then clears `.last_entry`.

**Rationale**: `flock` is available on all Linux systems and is atomic. The `.last_entry` file approach requires no parsing of the log file's full history — it's O(1) to record on write and O(lines-on-that-day) to remove on undo.

```bash
write_entry() {
    local date_key="$1"   # DD.MM.YYYY
    local text="$2"
    (
        flock -w 5 9 || { echo "Error: could not acquire log lock" >&2; exit 1; }
        # ... append entry ...
    ) 9>"/tmp/wlog_${USER}.lock"
    # record for undo
    echo "$date_key"     > "$WLOG_LAST_ENTRY"
    echo "- [ ] $text"  >> "$WLOG_LAST_ENTRY"
}
```
