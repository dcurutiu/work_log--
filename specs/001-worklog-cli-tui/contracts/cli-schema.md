# CLI Contract: wlog

**Type**: Shell CLI — command schema, exit codes, I/O protocol  
**Date**: 2026-05-28  
**Branch**: `001-worklog-cli-tui`

---

## Command Schema

### Synopsis

```
wlog [COMMAND] [OPTIONS]
```

### Commands & Options

| Invocation    | Mode            | Description                                               |
| ------------- | --------------- | --------------------------------------------------------- |
| `wlog`        | CLI read        | Print today's and yesterday's (workday-aware) activities  |
| `wlog -y`     | CLI read        | Print yesterday's activities (workday-aware)              |
| `wlog -t`     | CLI read        | Print tomorrow's activities (workday-aware)               |
| `wlog -p N`   | CLI read        | Print activities N calendar days in the past              |
| `wlog -f N`   | CLI read        | Print activities N calendar days in the future            |
| `wlog +`      | TUI write       | Open text-input TUI to add an entry for today             |
| `wlog + -y`   | TUI write       | Add entry for yesterday (workday-aware)                   |
| `wlog + -t`   | TUI write       | Add entry for tomorrow (workday-aware)                    |
| `wlog + -p N` | TUI write       | Add entry for N calendar days ago                         |
| `wlog + -f N` | TUI write       | Add entry for N calendar days ahead                       |
| `wlog -c`     | TUI interactive | Open full-screen calendar view (yesterday/today/tomorrow) |
| `wlog -a`     | CLI side-effect | Convert log to HTML and open in system browser            |
| `wlog --undo` | CLI write       | Remove the most recently added entry                      |
| `wlog -h`     | CLI info        | Print help message                                        |

### Date selector flags (combinable with `+`)

| Flag   | Meaning                               | Weekend skip?                                     |
| ------ | ------------------------------------- | ------------------------------------------------- |
| `-y`   | yesterday                             | Yes — if yesterday is Sunday, resolves to Friday  |
| `-t`   | tomorrow                              | Yes — if tomorrow is Saturday, resolves to Monday |
| `-p N` | N days in the past (N ≥ 1, integer)   | No                                                |
| `-f N` | N days in the future (N ≥ 1, integer) | No                                                |

### Argument validation

- `N` for `-p` and `-f` must be a positive integer. Non-integer or negative value: print error to stderr, exit 1.
- `wlog +` requires no positional arguments (description is entered interactively).
- Unknown flags: print error to stderr + suggest `wlog -h`, exit 1.

---

## Exit Codes

| Code  | Meaning                                                |
| ----- | ------------------------------------------------------ |
| `0`   | Success (including empty result — day has no entries)  |
| `1`   | User error (bad arguments, invalid N)                  |
| `2`   | Runtime error (file lock timeout, log file unreadable) |
| `130` | Interrupted (user pressed Ctrl+C / Escape in TUI)      |

---

## stdout Protocol

### CLI read mode (`wlog`, `wlog -y`, `wlog -p N`, etc.)

Output is human-readable, colorized when stdout is a TTY; plain when piped.

**Format per date section**:
```
### 28.05.2026

  [ ] Waiting magnification target images from manuel
  [x] Try to build other pipelines
```

- Date heading line: `### DD.MM.YYYY`
- Entry line: `  [ ] text` or `  [x] text` (2-space indent)
- Blank line between date sections
- Color applied via `$COLOR_*` variables (suppressed when `[ ! -t 1 ]`)

**Empty day**:
```
### 28.05.2026

  (no entries)
```

### `wlog -h` output

```
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
  ~/.config/wlog/theme.sh    Color theme overrides
```

### `wlog --undo` output

Success:
```
Removed: [28.05.2026] - [ ] Entry text that was removed
```

Nothing to undo:
```
Nothing to undo.
```

---

## stderr Protocol

All error messages go to stderr. Format: `wlog: <message>`.

Examples:
```
wlog: invalid argument for -p: must be a positive integer
wlog: could not acquire log file lock (timeout 5s)
wlog: log file not found: /path/to/worklog.md
```

---

## Environment Variables

| Variable     | Default                          | Description                                   |
| ------------ | -------------------------------- | --------------------------------------------- |
| `WLOG_FILE`  | `~/.local/share/wlog/worklog.md` | Override log file path                        |
| `WLOG_THEME` | `~/.config/wlog/theme.sh`        | Override theme file path                      |
| `NO_COLOR`   | unset                            | If set to any value, disable all color output |

---

## TUI Contract: `wlog +` (text input)

**Trigger**: `wlog +` with optional date flag  
**Behavior**: Clears a single-line input area, shows target date as context, accepts `read -e` line input with readline editing.

```
Add activity for 28.05.2026 (Enter to save, Ctrl+C to cancel):
> _
```

- Tab completion: disabled
- Readline history: disabled (no `HISTFILE` pollution)
- On Enter with non-empty text: save entry, print confirmation, exit 0
- On Enter with empty text: prompt again (do not save empty entries)
- On Ctrl+C / Escape: print "Cancelled." to stderr, exit 130

---

## TUI Contract: `wlog -c` (calendar view)

**Trigger**: `wlog -c`  
**Behavior**: Full-screen, alternate screen buffer (`tput smcup`/`tput rmcup`)

**Layout** (80-column terminal assumed; adapts to `$COLUMNS`):
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  WorkLog++   Date: [28.05.2026]   [◄ Yesterday]  [Today]  [Tomorrow ►]      │
├──────────────────┬──────────────────────────────┬──────────────────────────┤
│  27.05.2026      │  28.05.2026 (today)           │  29.05.2026              │
│  ─────────────   │  ─────────────────────────── │  ─────────────           │
│  [x] Task A      │  [ ] Waiting for images      │  (no entries)            │
│  [x] Task B      │  [ ] Build pipelines         │                          │
│                  │ ►[ ] Build docker images      │                          │
│                  │                               │                          │
├──────────────────┴──────────────────────────────┴──────────────────────────┤
│  ↑↓ navigate  Tab: switch column  Enter: toggle  d: delete  q: quit        │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Keyboard bindings**:

| Key                | Action                                                           |
| ------------------ | ---------------------------------------------------------------- |
| `↑` / `↓`          | Move selection within current column                             |
| `←` / `→` or `Tab` | Switch focus between columns (yesterday / today / tomorrow)      |
| `Enter`            | Toggle checked/unchecked on selected entry                       |
| `d`                | Prompt "Delete? [y/N]" → confirm with `y` removes entry from log |
| `n` / `+`          | Open add-entry input for the currently focused date              |
| `[` / `]`          | Shift center date -1 / +1 day (workday-aware for named steps)    |
| `q` / `Escape`     | Exit TUI, restore terminal                                       |

**On exit**: Terminal state fully restored (`tput rmcup`, `stty` reset, cursor visible).
