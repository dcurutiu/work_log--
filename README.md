# WorkLog++

A lightweight shell-script tool for logging daily work activities — no dependencies beyond standard Unix utilities.

Works from **bash** and **fish** shells. Runs on Linux and WSL.

---

## Install

```bash
git clone <repo-url>
cd work_log++
bash src/install.sh
```

Then add `~/.local/bin` to your PATH if it isn't already:

```bash
# bash / zsh — add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"

# fish — run once
fish_add_path ~/.local/bin
```

Verify:

```bash
wlog -h
```

---

## Usage

### Add an activity

```bash
wlog +
```

A prompt appears for today. Type your activity and press Enter.

```
Add activity for 28.05.2026 (Enter to save, Ctrl+C to cancel):
> Reviewed PR for the auth module
Saved: [28.05.2026] - [ ] Reviewed PR for the auth module
```

Add to a different day:

```bash
wlog + -y       # yesterday (weekend-aware: Sun → Fri)
wlog + -t       # tomorrow  (weekend-aware: Sat → Mon)
wlog + -p 3     # 3 calendar days ago
wlog + -f 1     # 1 calendar day ahead
```

### View activities

```bash
wlog            # today + yesterday (default)
wlog -y         # yesterday only
wlog -t         # tomorrow only
wlog -p 5       # 5 days ago
wlog -f 2       # 2 days from now
```

Example output:

```
### 27.05.2026

  [x] Reviewed PR for the auth module
  [ ] Write release notes

### 28.05.2026

  [ ] Stand-up sync
  [ ] Deploy to staging
```

### Undo last entry

```bash
wlog --undo
```

Removes the most recently added entry and prints confirmation. Running it again when there's nothing left prints `Nothing to undo.`

### Interactive calendar TUI

```bash
wlog -c
```

Opens a full-screen three-column view (yesterday / today / tomorrow):

| Key              | Action                               |
| ---------------- | ------------------------------------ |
| `↑` `↓`          | Move cursor between entries          |
| `←` `→` or `Tab` | Switch between day columns           |
| `Enter`          | Toggle `[ ]` ↔ `[x]`                 |
| `n`              | Add new entry to the focused day     |
| `d` then `y`     | Delete selected entry (with confirm) |
| `[` / `]`        | Shift view one workday back/forward  |
| `q` or `Esc`     | Quit                                 |

### HTML preview

```bash
wlog -a
```

Converts your log file to HTML and opens it in the system browser. On WSL this opens your Windows default browser.

---

## Log file format

Entries are stored in plain Markdown at `~/.local/share/wlog/worklog.md`:

```markdown
## May 2026

### 28.05.2026

- [ ] Stand-up sync
- [x] Deploy to staging
```

You can edit this file directly in any text editor.

---

## Configuration

### Override the log file path

```bash
# Temporarily
WLOG_FILE=~/Dropbox/worklog.md wlog

# Permanently — create ~/.config/wlog/config.sh
WLOG_FILE="$HOME/Dropbox/worklog.md"
```

### Customize colors

Edit `~/.config/wlog/theme.sh`. Available variables:

| Variable              | What it colors                   |
| --------------------- | -------------------------------- |
| `COLOR_TODAY`         | Today's date heading             |
| `COLOR_YESTERDAY`     | Yesterday's date heading         |
| `COLOR_TOMORROW`      | Tomorrow's date heading          |
| `COLOR_CHECKED`       | Completed entries `[x]`          |
| `COLOR_UNCHECKED`     | Pending entries `[ ]`            |
| `COLOR_DATE_HEADING`  | Generic date heading             |
| `COLOR_MONTH_HEADING` | Month section heading            |
| `COLOR_HIGHLIGHT`     | TUI cursor / accent              |
| `COLOR_BORDER`        | Separators and empty-state text  |
| `COLOR_RESET`         | Reset sequence (keep as default) |

Example:

```bash
# Bold green for today's heading
COLOR_TODAY="\033[1;32m"
```

### Disable color

```bash
NO_COLOR=1 wlog
```

---

## Weekend-aware date resolution

`-y`, `-t`, and the default view skip weekends when resolving "yesterday" and "tomorrow":

- **Yesterday on Monday** → Friday
- **Tomorrow on Friday** → Monday
- `-p N` and `-f N` are raw calendar offsets (no weekend skip)

---

## Uninstall

```bash
rm ~/.local/bin/wlog ~/.local/bin/wlog-tui
# Optionally remove data and config:
rm -rf ~/.config/wlog ~/.local/share/wlog
```

---

## Requirements

- bash 4+ (bash 5 recommended)
- Standard utilities: `awk`, `sed`, `grep`, `date` (GNU), `tput`, `stty`, `flock`
- No external dependencies
