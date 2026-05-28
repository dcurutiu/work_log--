# Data Model: WorkLog++ CLI & TUI Activity Logger

**Phase**: 1 — Design  
**Date**: 2026-05-28  
**Branch**: `001-worklog-cli-tui`

---

## Entities

### 1. LogFile

The single source of truth for all work activities.

| Attribute          | Value                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------ |
| Default path       | `~/.local/share/wlog/worklog.md`                                                                             |
| Override mechanism | `WLOG_FILE` environment variable; or `WLOG_FILE=...` line in `~/.config/wlog/config.sh` (sourced at startup) |
| Format             | Plain-text Markdown; UTF-8                                                                                   |
| Structure          | Two-level date hierarchy (see below)                                                                         |
| Locking            | `flock` on `/tmp/wlog_${USER}.lock` for all writes                                                           |

**File structure**:
```markdown
## May 2026

### 27.05.2026

- [x] Test LIA loading bay monitor duration for prefiltering
- [x] Discussion with manuel. try to save images during magnification calibration
- [ ] Small test with docker image for CAR created on OpenShift

### 28.05.2026

- [ ] Waiting magnification target images from manuel

--------------------
## June 2026

### 02.06.2026

### 03.06.2026
```

**Heading format rules**:
- Month section: `## <Month Name> <YYYY>` (e.g., `## May 2026`)
- Day section: `### DD.MM.YYYY` (e.g., `### 28.05.2026`)
- Month sections are created on demand when the first entry for a new month is added
- Day sections are created on demand when the first entry for a new day is added
- Empty day sections (no entries) are valid (pre-created by the user's prior workflow)
- Separator between months: `--------------------` (20 dashes, matching prior workflow)

---

### 2. ActivityEntry

A single work activity item within a day section.

| Attribute | Type                | Description                                            |
| --------- | ------------------- | ------------------------------------------------------ |
| `date`    | string `DD.MM.YYYY` | The calendar date this entry belongs to                |
| `text`    | string              | The activity description (arbitrary text, single line) |
| `checked` | boolean             | `true` = `- [x]`, `false` = `- [ ]`                    |

**Markdown representation**:
```markdown
- [ ] Unchecked activity description here
- [x] Checked (completed) activity description here
```

**Validation rules**:
- `text` must be non-empty (enforced at input time)
- `text` is single-line; newlines within text are not supported
- `text` may contain any printable characters including `[`, `]`, `-`
- Entries are appended to the day section; insertion order = chronological order

**State transitions**:
```
[ ] unchecked  ──(toggle)──►  [x] checked
[x] checked    ──(toggle)──►  [ ] unchecked
```

Toggle modifies the `worklog.md` file in-place using `sed`.

---

### 3. UndoState

Ephemeral record of the most recently written entry, enabling `wlog --undo`.

| Attribute | Value                                                                      |
| --------- | -------------------------------------------------------------------------- |
| Path      | `~/.local/share/wlog/.last_entry`                                          |
| Format    | 2 lines: line 1 = `DD.MM.YYYY`, line 2 = full entry text (`- [ ] ...`)     |
| Lifecycle | Written after every successful `wlog +` write; cleared after `wlog --undo` |
| Absence   | If file missing or empty, `--undo` prints "Nothing to undo." and exits 0   |

---

### 4. ThemeConfig

Color configuration for TUI and CLI output.

| Attribute          | Value                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------- |
| Default path       | `src/theme-default.sh` (ships with tool; copied to `~/.config/wlog/theme.sh` by install.sh) |
| User override path | `~/.config/wlog/theme.sh` (sourced after defaults if present)                               |
| Format             | Bash variable assignments only; no function definitions; no side effects                    |

**Color variables**:
```bash
# Terminal color escape codes (ANSI)
COLOR_TODAY="\033[1;37m"        # Bold white — today's heading
COLOR_YESTERDAY="\033[0;36m"    # Cyan — yesterday's heading
COLOR_TOMORROW="\033[0;35m"     # Magenta — tomorrow's heading
COLOR_CHECKED="\033[0;32m"      # Green — checked entries
COLOR_UNCHECKED="\033[0;33m"    # Yellow — unchecked entries
COLOR_DATE_HEADING="\033[1;34m" # Bold blue — date headings in output
COLOR_MONTH_HEADING="\033[1;33m"# Bold yellow — month headings in output
COLOR_RESET="\033[0m"           # Reset
COLOR_HIGHLIGHT="\033[7m"       # Reverse video — selected item in -c TUI
COLOR_BORDER="\033[0;90m"       # Dark gray — TUI borders/separators
```

---

### 5. GeneratedHTML

Ephemeral HTML file produced by `wlog -a`.

| Attribute  | Value                                                                    |
| ---------- | ------------------------------------------------------------------------ |
| Path       | `~/.local/share/wlog/worklog.html`                                       |
| Generation | `awk` program embedded in `wlog.sh`; regenerated on every `wlog -a` call |
| Lifecycle  | Overwritten each run; not version-controlled; may be deleted safely      |

---

## Date Calculation Model

### Calendar date representation

All dates are stored and compared as `DD.MM.YYYY` strings in the log file.  
All internal date arithmetic uses ISO `YYYY-MM-DD` format (GNU `date` compatible).

**Conversion functions** (implemented in `wlog.sh`):
```
log_to_iso("DD.MM.YYYY")  →  "YYYY-MM-DD"
iso_to_log("YYYY-MM-DD")  →  "DD.MM.YYYY"
month_heading("YYYY-MM-DD") →  "Month YYYY"   (e.g., "May 2026")
```

### Workday resolution (weekend skip)

Applies only to named shortcuts: `-y` (yesterday), `-t` (tomorrow), and the default `wlog` view's "yesterday" context.  
Does **not** apply to `-p N` or `-f N` (raw calendar offsets).

| Shortcut         | Direction | Saturday result       | Sunday result         |
| ---------------- | --------- | --------------------- | --------------------- |
| `-t` / tomorrow  | +1        | Monday (+2 from base) | Monday (+1 from Sat)  |
| `-y` / yesterday | -1        | Friday (-1 from base) | Friday (-2 from base) |

See [research.md](research.md#r-002-gnu-date-weekend-skip-logic) for the `resolve_workday()` implementation.

### Default view date pair

`wlog` (no args) shows two date sections:
1. **Today**: `$(date +%Y-%m-%d)` — no weekend skip applied to today itself
2. **Yesterday**: `resolve_workday(today, -1)` — weekend-aware

---

## File I/O Operations

| Operation                                | Implementation                                                                                                | Atomic?                                    |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| Append entry to existing day section     | `awk` rewrite of file: find `### DD.MM.YYYY` heading, insert after last entry in that section                 | Yes (write to temp, `mv`)                  |
| Create new day section in existing month | `awk` rewrite: find `## Month YYYY`, append `### DD.MM.YYYY\n\n` before next `##` or EOF                      | Yes                                        |
| Create new month + day section           | `awk` rewrite: append `\n--------------------\n## Month YYYY\n\n### DD.MM.YYYY\n\n` at EOF                    | Yes                                        |
| Toggle entry checked state               | `sed -i` in-place: match exact line `- [ ] text` → `- [x] text` (or reverse) on the first match for that date | Near-atomic (sed -i uses temp file on GNU) |
| Remove entry (undo / TUI delete)         | `awk` rewrite: skip the matching line                                                                         | Yes                                        |
| Read day entries                         | `awk`: extract lines between `### DD.MM.YYYY` and next `###`/`##`/EOF                                         | Read-only                                  |
