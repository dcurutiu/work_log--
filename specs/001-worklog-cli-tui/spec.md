# Feature Specification: WorkLog++ CLI & TUI Activity Logger

**Feature Branch**: `001-worklog-cli-tui`
**Created**: 2026-05-28
**Status**: Draft
**Input**: User description: "what.md"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Today's & Yesterday's Activities (Priority: P1)

A user opens a terminal and types `wlog` from anywhere on the machine. The app prints a clear, readable summary of today's and yesterday's activities — showing each item as checked or unchecked — without needing to open any editor.

**Why this priority**: This is the core read path. It replaces the daily habit of opening VS Code just to glance at what was done. It must work with zero friction.

**Independent Test**: Can be fully tested by running `wlog` in a terminal where at least one log entry exists for today or yesterday; delivers a readable activity list.

**Acceptance Scenarios**:

1. **Given** at least one activity exists for today, **When** the user runs `wlog`, **Then** today's activities are printed with date heading, each item showing `[x]` or `[ ]` status.
2. **Given** activities exist for both today and yesterday, **When** the user runs `wlog`, **Then** both days are shown in chronological order, visually separated.
3. **Given** no activities exist for today, **When** the user runs `wlog`, **Then** today's section shows an empty state message and yesterday's entries are still shown.

---

### User Story 2 - Add a New Activity via TUI (Priority: P2)

A user runs `wlog +` to open a minimal interactive text box where they type a new activity description. After confirming, the activity is saved as an unchecked item for the target date (defaults to today). Date can be shifted with flags.

**Why this priority**: Writing new entries is the second most frequent operation. The TUI box avoids the need to manage file paths or learn a file format.

**Independent Test**: Can be fully tested by running `wlog +`, entering text, confirming, then running `wlog` to verify the entry appears.

**Acceptance Scenarios**:

1. **Given** the user runs `wlog +`, **When** the TUI text box opens and the user types a description and confirms, **Then** the activity is appended as an unchecked item for today.
2. **Given** the user runs `wlog + -y`, **When** the user enters a description and confirms, **Then** the activity is saved under yesterday's date.
3. **Given** the user runs `wlog + -p 3`, **When** the user enters a description and confirms, **Then** the activity is saved under the date 3 days ago.
4. **Given** the user presses Escape or Ctrl+C in the TUI, **When** the box is open, **Then** no entry is saved and the terminal returns cleanly.

---

### User Story 3 - Browse Activities in Full TUI Calendar View (Priority: P3)

A user runs `wlog -c` to open a full-screen interactive TUI showing today's, yesterday's, and tomorrow's activities in a single view. Items are color-coded by day. A date selector allows jumping to any date. Quick buttons ("Yesterday", "Tomorrow") shift the view. Entries can be checked/unchecked directly in this view.

**Why this priority**: Power users benefit from a richer view when reviewing a week or checking off completed items.

**Independent Test**: Can be fully tested by running `wlog -c` and navigating between days, verifying color distinction, date selector, and check-toggle functionality.

**Acceptance Scenarios**:

1. **Given** the user runs `wlog -c`, **When** the TUI opens, **Then** three columns/sections show yesterday, today, and tomorrow in chronological order with distinct color tinting.
2. **Given** the TUI is open, **When** the user uses Tab to focus the date input field and types or arrow-keys to a date, **Then** the displayed entries shift to the selected date and its neighbors.
3. **Given** the TUI is open on a date with activities, **When** the user navigates to an item with arrow keys and presses Enter, **Then** the item's checked/unchecked status toggles immediately in both the TUI and the underlying log file.
4. **Given** the user presses Tab to focus the "Yesterday" or "Tomorrow" shortcut, **When** Enter is pressed, **Then** the date selector jumps to that date.
5. **Given** the user navigates to an entry and presses `d`, **When** a confirmation prompt appears and the user confirms, **Then** the entry is deleted from the log file.

---

### User Story 4 - View Activities for Relative Past or Future Dates (Priority: P2)

A user runs `wlog -p 5` (or `wlog -f 3`, `wlog -y`, `wlog -t`) to view activities for a specific relative date without opening the TUI.

**Why this priority**: Reviewing what was done last week or planning future days is a common secondary read operation.

**Independent Test**: Can be fully tested by adding entries for varied dates and verifying that each date flag returns the correct date's entries.

**Acceptance Scenarios**:

1. **Given** activities exist 5 days ago, **When** the user runs `wlog -p 5`, **Then** only that date's activities are printed.
2. **Given** the user runs `wlog -y`, **When** executed, **Then** yesterday's activities are printed (equivalent to `wlog -p 1`).
3. **Given** the user runs `wlog -t`, **When** executed, **Then** tomorrow's planned items are printed (equivalent to `wlog -f 1`).
4. **Given** no entries exist for the requested date, **When** the command is run, **Then** an empty state message is shown for that date with no error.

---

### User Story 5 - Open HTML Preview of Full Log (Priority: P4)

A user runs `wlog -a` to open the complete work log as a rendered HTML page in the system browser (Edge via WSL).

**Why this priority**: Provides a polished way to share or review the full history without being in a terminal.

**Independent Test**: Can be fully tested by running `wlog -a` and verifying the browser opens with a rendered, readable version of the log.

**Acceptance Scenarios**:

1. **Given** the user runs `wlog -a`, **When** the command executes, **Then** the system browser opens with a rendered HTML version of the full work log.
2. **Given** the system is WSL, **When** `wlog -a` is run, **Then** the Windows default browser (Edge) is used to open the HTML file.

---

### Edge Cases

- What happens when the log file does not exist yet (first run)?
- What happens when a date argument to `-p` or `-f` is not a valid number?
- How does the TUI handle very long activity descriptions that exceed terminal width?
- What happens when the terminal does not support color (e.g., dumb terminal)?
- How does the app behave if two instances try to write to the log file simultaneously?
- What happens when `wlog --undo` is run but there are no entries in the log file?
- What happens when the user presses the delete key in `-c` TUI on an empty day with no entries?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The `wlog` command MUST be accessible from any directory on the machine without specifying a path.
- **FR-002**: Running `wlog` with no arguments MUST display today's and yesterday's activities, each with their checked/unchecked status.
- **FR-003**: Running `wlog +` MUST open an interactive text-input TUI for entering a new activity; the entry MUST be saved as unchecked for the target date.
- **FR-004**: The `+` subcommand MUST accept date-shifting flags: `-y` (yesterday), `-t` (tomorrow), `-p N` (N days in the past), `-f N` (N days in the future).
- **FR-005**: Running `wlog -c` MUST open a full-screen TUI showing activities for yesterday, today, and tomorrow simultaneously with distinct per-day color tinting.
- **FR-006**: The TUI calendar view (`-c`) MUST be fully keyboard-driven: arrow keys navigate between entries, Tab cycles focus between widgets (day columns, date input, Yesterday/Tomorrow shortcuts), Enter toggles or confirms, `d` initiates delete with a confirmation prompt, and `q`/Escape exits.
- **FR-007**: The TUI calendar view MUST include a date input field and "Yesterday"/"Tomorrow" keyboard-accessible shortcuts; selecting either shifts the center date accordingly.
- **FR-008-toggle**: The TUI calendar view MUST allow the user to toggle the checked/unchecked status of any activity via Enter, persisting the change immediately to the log file.
- **FR-008**: Running `wlog -p N` MUST display activities for the date N days in the past; `wlog -f N` MUST display activities for the date N days in the future.
- **FR-009**: Running `wlog -y` MUST display yesterday's activities; `wlog -t` MUST display tomorrow's activities.
- **FR-010**: Running `wlog -a` MUST convert the log file to HTML using a built-in `awk`/`sed` converter (no external tools required) covering: `##`/`###` headings, `- [ ]`/`- [x]` checkboxes, and `---` horizontal rules; the resulting HTML file MUST be opened in the system browser (on WSL: the Windows browser).
- **FR-011**: Running `wlog -h` MUST display a help message listing all available commands and flags.
- **FR-012**: All activity data MUST be stored in a single plain-text Markdown file using checkbox syntax (`- [ ]` / `- [x]`), organized with two-level date headings: `## Month YYYY` monthly sections containing `### DD.MM.YYYY` daily sub-headings.
- **FR-013**: The color scheme MUST be configurable via a sourced shell file (`~/.config/wlog/theme.sh`) that exports named color variables (e.g., `COLOR_TODAY`, `COLOR_YESTERDAY`, `COLOR_TOMORROW`, `COLOR_CHECKED`, `COLOR_RESET`); the script MUST ship a default theme file and `source` the user's override if present.
- **FR-014**: The log file location MUST default to a fixed known path but MUST be overridable via an environment variable or config file.
- **FR-015**: Running `wlog --undo` MUST remove the most recently added entry from the log file and confirm the removed text to the user.
- **FR-016**: The TUI calendar view (`-c`) MUST allow the user to delete a selected activity entry by pressing a designated key (e.g., `d` or `Delete`), with a confirmation prompt before removal.

### Key Entities

- **Log File**: The single Markdown file storing all activities; organized with `## Month YYYY` monthly sections and `### DD.MM.YYYY` daily sub-headings (e.g., `## May 2026` → `### 28.05.2026`); each entry is a checkbox list item.
- **Activity Entry**: A single logged item with a description, a date, and a checked/unchecked status.
- **Theme Config**: A shell-sourceable file at `~/.config/wlog/theme.sh` exporting terminal color variables (`COLOR_TODAY`, `COLOR_YESTERDAY`, `COLOR_TOMORROW`, `COLOR_CHECKED`, `COLOR_RESET`, etc.); a default theme ships with the tool and is overridden by the user file if present.

## Clarifications

### Session 2026-05-28

- Q: Should the app support deleting activities, and if so via which interface? → A: Both — `wlog --undo` removes the last added entry via CLI, and the `-c` TUI allows selecting and deleting any entry with a confirmation prompt.
- Q: What heading structure should the log file use for date organization? → A: Two-level hierarchy — `## Month YYYY` monthly sections containing `### DD.MM.YYYY` daily sub-headings, matching the user's prior workflow.
- Q: What is the TUI navigation model for the `-c` calendar view? → A: Keyboard-only — arrow keys navigate entries, Tab cycles between widgets, Enter toggles/confirms, `d` + confirmation prompt deletes, `q`/Escape exits; no mouse support required.
- Q: How should `wlog -a` convert Markdown to HTML? → A: Built-in `awk`/`sed` converter within the script — covers `##`/`###` headings, `- [ ]`/`- [x]` checkboxes, and `---` rules; no external tools (pandoc, python3, etc.) required.
- Q: What format and location should the theme/color config file use? → A: Sourced shell file at `~/.config/wlog/theme.sh` exporting named color variables (e.g., `COLOR_TODAY`, `COLOR_YESTERDAY`); default theme ships with the tool, user file overrides if present.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new activity can be added and confirmed in under 15 seconds from running `wlog +` to returning to the shell prompt.
- **SC-002**: Running `wlog` (read path) completes and prints output in under 1 second on any machine where the tool is installed.
- **SC-003**: The tool installs (copies to PATH) in a single command with no additional package manager or runtime required.
- **SC-004**: All commands work correctly on any POSIX-compatible shell (bash 4+, zsh) without modification.
- **SC-005**: The log file remains valid Markdown at all times; opening it in any Markdown previewer renders correctly.
- **SC-006**: Changing the color theme requires editing only the theme config file; no script changes are needed.

## Assumptions

- The user is on a Linux/WSL environment with bash 4+ or zsh available.
- `tput` and standard Unix tools (`awk`, `sed`, `grep`, `date`) are available on the target machine.
- On WSL, the Windows browser (Edge) is accessible via `explorer.exe` or `wslview`/`xdg-open` WSL bridge.
- The log file is personal and single-user; no concurrent multi-user write scenarios need to be handled for v1.
- Mobile support is out of scope.
- The tool is installed by symlinking or copying the script to a directory on `$PATH` (e.g., `~/.local/bin`).
- "Checked" activities correspond to `- [x]` and "unchecked" to `- [ ]` in the Markdown log file.
- The theme config file (`~/.config/wlog/theme.sh`) is a shell script sourced at runtime; it must not execute side effects — only variable assignments.
- The date selector in the TUI (`-c`) does not need to support dates beyond ±30 days from today for v1.
