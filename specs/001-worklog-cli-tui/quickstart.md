# Quickstart: WorkLog++

**Date**: 2026-05-28  
**Branch**: `001-worklog-cli-tui`

---

## Install

```bash
# Clone or download the repo, then run:
bash src/install.sh
```

The install script:
1. Copies `src/wlog.sh` → `~/.local/bin/wlog` (executable)
2. Copies `src/wlog-tui.sh` → `~/.local/bin/wlog-tui` (executable)
3. Creates `~/.config/wlog/` and copies `src/theme-default.sh` → `~/.config/wlog/theme.sh`
4. Creates `~/.local/share/wlog/` (data directory)

**Add to PATH if not already present**:

For **bash** / zsh — add to `~/.bashrc` or `~/.zshrc`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

For **fish** — run once:
```fish
fish_add_path ~/.local/bin
```

Verify:
```bash
wlog -h
```

---

## First use

On first run, if no log file exists yet, `wlog` creates `~/.local/share/wlog/worklog.md` automatically with today's month section and day heading pre-populated.

---

## Add an activity

```bash
wlog +
```

A prompt appears:
```
Add activity for 28.05.2026 (Enter to save, Ctrl+C to cancel):
> 
```

Type your activity and press Enter. Done.

**For a different day**:
```bash
wlog + -y          # add to yesterday (workday-aware: Sun → Fri)
wlog + -t          # add to tomorrow (workday-aware: Sat → Mon)
wlog + -p 3        # add to 3 calendar days ago
wlog + -f 1        # add to tomorrow (same as -t but no weekend skip)
```

---

## View activities

```bash
wlog               # today + yesterday (yesterday is workday-aware)
wlog -y            # yesterday only (workday-aware)
wlog -t            # tomorrow only (workday-aware)
wlog -p 5          # 5 calendar days ago
wlog -f 2          # 2 calendar days from now
```

Example output:
```
### 27.05.2026

  [x] Test LIA loading bay monitor duration
  [x] Discussion with manuel

### 28.05.2026

  [ ] Waiting magnification target images from manuel
  [ ] Try to build other pipelines
```

---

## Interactive calendar view

```bash
wlog -c
```

Opens a full-screen three-column TUI showing yesterday, today, and tomorrow.

| Key              | Action                                    |
| ---------------- | ----------------------------------------- |
| `↑` `↓`          | Navigate entries                          |
| `←` `→` or `Tab` | Switch between day columns                |
| `Enter`          | Toggle `[ ]` ↔ `[x]`                      |
| `n`              | Add new entry to focused day              |
| `d`              | Delete selected entry (with confirmation) |
| `[` / `]`        | Shift view one workday back/forward       |
| `q`              | Exit                                      |

---

## Undo last entry

```bash
wlog --undo
```

Removes the most recently added entry and prints what was removed.

---

## Open HTML preview

```bash
wlog -a
```

Converts `worklog.md` to HTML and opens it in your system browser.  
On WSL, this opens Edge (or your Windows default browser).

---

## Customize colors

Edit `~/.config/wlog/theme.sh`:

```bash
# Example: make today's heading bold green instead of bold white
COLOR_TODAY="\033[1;32m"
```

Available variables: `COLOR_TODAY`, `COLOR_YESTERDAY`, `COLOR_TOMORROW`, `COLOR_CHECKED`, `COLOR_UNCHECKED`, `COLOR_DATE_HEADING`, `COLOR_MONTH_HEADING`, `COLOR_RESET`, `COLOR_HIGHLIGHT`, `COLOR_BORDER`.

To disable all color (e.g., for scripts):
```bash
NO_COLOR=1 wlog
```

---

## Override log file location

```bash
# Temporarily:
WLOG_FILE=~/Dropbox/worklog.md wlog

# Permanently — add to ~/.config/wlog/config.sh:
WLOG_FILE="$HOME/Dropbox/worklog.md"
```

---

## Uninstall

```bash
rm ~/.local/bin/wlog ~/.local/bin/wlog-tui
# Optionally remove data and config:
rm -rf ~/.config/wlog ~/.local/share/wlog
```
