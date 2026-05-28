---
description: "Task list for WorkLog++ CLI & TUI Activity Logger"
---

# Tasks: WorkLog++ CLI & TUI Activity Logger

**Input**: Design documents from `specs/001-worklog-cli-tui/`
**Branch**: `001-worklog-cli-tui`
**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Data Model**: [data-model.md](data-model.md) | **Contracts**: [contracts/cli-schema.md](contracts/cli-schema.md)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: User story label (US1–US5)
- All paths are relative to repository root

---

## Phase 1: Setup

**Purpose**: Create the repository source structure and install scaffold — no logic yet.

- [ ] T001 Create directory structure: `src/`, `tests/unit/`, `tests/integration/` at repo root
- [ ] T002 [P] Create `src/wlog.sh` with shebang `#!/usr/bin/env bash`, empty main() stub, and `set -euo pipefail`
- [ ] T003 [P] Create `src/wlog-tui.sh` with shebang `#!/usr/bin/env bash`, empty `tui_calendar()` stub, and `set -euo pipefail`
- [ ] T004 [P] Create `src/theme-default.sh` with all 10 color variable definitions from data-model.md (`COLOR_TODAY`, `COLOR_YESTERDAY`, `COLOR_TOMORROW`, `COLOR_CHECKED`, `COLOR_UNCHECKED`, `COLOR_DATE_HEADING`, `COLOR_MONTH_HEADING`, `COLOR_RESET`, `COLOR_HIGHLIGHT`, `COLOR_BORDER`)
- [ ] T005 Create `src/install.sh`: copies `wlog.sh` → `~/.local/bin/wlog`, `wlog-tui.sh` → `~/.local/bin/wlog-tui`; creates `~/.config/wlog/` and copies `theme-default.sh` → `~/.config/wlog/theme.sh` if not present; creates `~/.local/share/wlog/`; prints PATH setup instructions for bash and fish

**Checkpoint**: Run `bash src/install.sh` — no errors; `~/.local/bin/wlog` exists and is executable.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core shared library functions used by all user stories — date calc, file I/O, config loading, color loading.

- [ ] T006 Implement config loader in `src/wlog.sh`: `load_config()` sources `~/.config/wlog/config.sh` if present; sets `WLOG_FILE` default to `~/.local/share/wlog/worklog.md`; sets `WLOG_THEME` default to `~/.config/wlog/theme.sh`
- [ ] T007 Implement theme loader in `src/wlog.sh`: `load_theme()` sources `src/theme-default.sh` for defaults then sources `$WLOG_THEME` if file exists; respects `NO_COLOR` env var (blanks all color vars)
- [ ] T008 Implement date conversion helpers in `src/wlog.sh`: `log_to_iso()` converts `DD.MM.YYYY` → `YYYY-MM-DD`; `iso_to_log()` converts `YYYY-MM-DD` → `DD.MM.YYYY`; `month_heading()` converts `YYYY-MM-DD` → `Month YYYY` (e.g., `May 2026`)
- [ ] T009 Implement `resolve_workday()` in `src/wlog.sh`: takes `YYYY-MM-DD` base and direction (`+1`/`-1`); uses `date -d` + `date +%u`; Saturday+1→Monday, Sunday-1→Friday, Saturday-1→Friday, Sunday+1→Monday (see research.md R-002)
- [ ] T010 Implement `parse_day_entries()` in `src/wlog.sh`: takes `DD.MM.YYYY` date; uses `awk` to extract lines between `### DD.MM.YYYY` heading and the next `###`/`##`/EOF in `$WLOG_FILE`; outputs raw `- [ ]`/`- [x]` lines
- [ ] T011 Implement `ensure_day_section()` in `src/wlog.sh`: takes `DD.MM.YYYY`; creates month section (`## Month YYYY`) + 20-dash separator if month does not exist; creates `### DD.MM.YYYY` day section if it does not exist; uses atomic awk-rewrite → temp → `mv`; acquires `flock` lock
- [ ] T012 Implement `append_entry()` in `src/wlog.sh`: takes `DD.MM.YYYY` + text; calls `ensure_day_section()`; appends `- [ ] <text>` after last entry in that day section via awk-rewrite → `mv`; writes undo state to `~/.local/share/wlog/.last_entry` (line 1 = date, line 2 = entry text)
- [ ] T013 [P] Write unit test `tests/unit/test_date_calc.sh`: tests `log_to_iso`, `iso_to_log`, `month_heading`, and `resolve_workday` for Mon/Fri/Sat/Sun inputs; exits 0 if all pass

**Checkpoint**: Run `bash tests/unit/test_date_calc.sh` — exits 0.

---

## Phase 3: User Story 1 — View Today's & Yesterday's Activities (Priority: P1) 🎯 MVP

**Goal**: `wlog` (no args) prints today's and yesterday's (workday-aware) activities with color, formatted per contracts/cli-schema.md.

**Independent Test**: Manually add 2 entries to `worklog.md` for today and 2 for yesterday (or use `wlog +`), then run `wlog` — both date sections appear with correct `[x]`/`[ ]` formatting.

- [ ] T014 [US1] Implement `print_day()` in `src/wlog.sh`: takes `DD.MM.YYYY`; calls `parse_day_entries()`; prints `### DD.MM.YYYY` heading with `$COLOR_DATE_HEADING`; prints each entry with `$COLOR_CHECKED`/`$COLOR_UNCHECKED`; prints `(no entries)` if empty; suppresses color when `[ ! -t 1 ]`
- [ ] T015 [US1] Implement default command handler in `src/wlog.sh` (no args): resolves today (`date +%Y-%m-%d` → `iso_to_log`); resolves yesterday via `resolve_workday(today, -1)`; calls `print_day()` for yesterday then today
- [ ] T016 [P] [US1] Implement `-y` flag handler in `src/wlog.sh`: resolves yesterday via `resolve_workday`; calls `print_day()` for that single date
- [ ] T017 [P] [US1] Implement `-h` flag handler in `src/wlog.sh`: prints help text verbatim from contracts/cli-schema.md help section to stdout; exits 0
- [ ] T018 [P] [US1] Write integration test `tests/integration/test_read_entry.sh`: seeds `$WLOG_FILE` with known entries for today and yesterday; runs `wlog`; asserts both date headings and entry text appear in output; exits 0 if all pass

**Checkpoint**: Run `wlog` — readable two-day output with color. Run `bash tests/integration/test_read_entry.sh` — exits 0.

---

## Phase 4: User Story 4 — View Activities for Relative Past/Future Dates (Priority: P2)

**Goal**: `wlog -p N`, `wlog -f N`, `wlog -t` each print the correct single date's activities.

**Independent Test**: Add entries for 3 days ago; run `wlog -p 3` — only that date's entries print. Run `wlog -t` on a Friday — Monday's (or an empty) section prints.

- [ ] T019 [US4] Implement `-p N` flag handler in `src/wlog.sh`: validates N is a positive integer (stderr + exit 1 on invalid); computes `date -d "today -N days" +%Y-%m-%d` → `iso_to_log`; calls `print_day()`
- [ ] T020 [US4] Implement `-f N` flag handler in `src/wlog.sh`: validates N is a positive integer; computes `date -d "today +N days"`; calls `print_day()`
- [ ] T021 [US4] Implement `-t` flag handler in `src/wlog.sh`: resolves tomorrow via `resolve_workday(today, +1)`; calls `print_day()`
- [ ] T022 [P] [US4] Add argument validation in `src/wlog.sh` main(): unknown flags → stderr message + suggest `wlog -h` + exit 1; missing N after `-p`/`-f` → stderr + exit 1
- [ ] T023 [P] [US4] Extend integration test `tests/integration/test_read_entry.sh` with `-p`, `-f`, `-y`, `-t` cases; assert correct dates and empty-state messages

**Checkpoint**: Run `wlog -p 2`, `wlog -f 1`, `wlog -t` — each prints exactly one date section.

---

## Phase 5: User Story 2 — Add a New Activity via TUI (Priority: P2)

**Goal**: `wlog +` opens an inline text prompt, saves the entry, and returns to the shell. Date flags work.

**Independent Test**: Run `wlog +`, enter "test activity", press Enter; run `wlog` — new entry appears as `[ ] test activity` for today.

- [ ] T024 [US2] Implement `tui_add_entry()` in `src/wlog.sh`: prints target date context line; uses `read -e -p "> " text` loop (re-prompts on empty input); on Ctrl+C traps SIGINT → prints "Cancelled." to stderr, exits 130; on Enter with non-empty text calls `append_entry()` and prints confirmation line
- [ ] T025 [US2] Wire `wlog +` main handler: parses optional date flag (`-y`, `-t`, `-p N`, `-f N`) to resolve target date; calls `tui_add_entry()` with that date
- [ ] T026 [P] [US2] Write integration test `tests/integration/test_add_entry.sh`: uses here-string `echo "test entry" | wlog +` (piped non-interactive); asserts entry appears in `$WLOG_FILE` for today; exits 0

**Checkpoint**: Run `wlog +` interactively — prompt appears, entry saves, `wlog` shows it. Run `bash tests/integration/test_add_entry.sh` — exits 0.

---

## Phase 6: User Story 2 (cont.) — Undo Last Entry

**Goal**: `wlog --undo` removes the most recently added entry.

**Independent Test**: Run `wlog +` to add an entry; run `wlog --undo` — entry is removed from output of `wlog`; running `wlog --undo` again prints "Nothing to undo."

- [ ] T027 [US2] Implement `cmd_undo()` in `src/wlog.sh`: reads `~/.local/share/wlog/.last_entry`; if missing/empty prints "Nothing to undo." and exits 0; otherwise reads date (line 1) and entry text (line 2); removes first matching line from `$WLOG_FILE` via awk-rewrite → `mv` with `flock`; clears `.last_entry`; prints `Removed: [date] <entry text>`
- [ ] T028 [P] [US2] Write integration test `tests/integration/test_undo.sh`: adds entry via `append_entry()`, runs `wlog --undo`, asserts entry is gone from file, asserts second `--undo` prints "Nothing to undo."; exits 0

**Checkpoint**: Run `bash tests/integration/test_undo.sh` — exits 0.

---

## Phase 7: User Story 3 — Full TUI Calendar View (Priority: P3)

**Goal**: `wlog -c` opens a full-screen three-column keyboard-driven TUI showing yesterday / today / tomorrow with toggle, delete, and day-shift.

**Independent Test**: Run `wlog -c` — three columns render; press Down to move cursor, Enter to toggle an item (verify file changes), `d`+`y` to delete (verify removal), `]` to shift one day forward, `q` to quit cleanly (terminal restored).

- [ ] T029 [US3] Implement `tui_enter()` / `tui_exit()` in `src/wlog-tui.sh`: `tui_enter()` saves `stty -g`, sets `stty raw -echo`, calls `tput smcup`/`tput civis`; `tui_exit()` calls `tput cnorm`/`tput rmcup`, restores stty; registers `trap 'tui_exit' EXIT INT TERM`
- [ ] T030 [US3] Implement `read_key()` in `src/wlog-tui.sh`: reads single keypress with `read -rsn1`; if ESC reads 2 more bytes with 0.1s timeout; returns named key token: `UP`, `DOWN`, `LEFT`, `RIGHT`, `ENTER`, `TAB`, `ESC`, `d`, `n`, `[`, `]`, `q`, or raw char
- [ ] T031 [US3] Implement `render_calendar()` in `src/wlog-tui.sh`: takes three `DD.MM.YYYY` dates (left/center/right); clears screen; draws three-column layout using `tput cup`; applies per-column colors from theme; shows `►` cursor on selected entry; draws status bar with key hints at bottom row
- [ ] T032 [US3] Implement main TUI event loop in `src/wlog-tui.sh` `tui_calendar()`: maintains state (left/center/right dates, focused column, cursor row); calls `render_calendar()` each iteration; processes `read_key()` output: Up/Down moves cursor, Left/Right/Tab switches column, `[`/`]` shifts dates via `resolve_workday`, Enter calls `toggle_entry()`, `d` prompts confirm then calls `remove_entry()`, `n` calls inline add prompt, `q`/ESC calls `tui_exit` and returns
- [ ] T033 [US3] Implement `toggle_entry()` in `src/wlog.sh`: takes `DD.MM.YYYY` + entry text; uses `sed` in-place to swap `- [ ]` ↔ `- [x]` on first exact match for that date's section via awk section-aware rewrite
- [ ] T034 [US3] Implement `remove_entry()` in `src/wlog.sh`: takes `DD.MM.YYYY` + entry text; removes matching line via awk-rewrite → `mv` with `flock`; used by both `--undo` (via `cmd_undo`) and TUI delete
- [ ] T035 [P] [US3] Wire `wlog -c` in `src/wlog.sh` main(): sources `src/wlog-tui.sh` (or `~/.local/bin/wlog-tui`); calls `tui_calendar()` with today's workday-adjacent dates

**Checkpoint**: Run `wlog -c` — TUI renders, all keyboard bindings work, terminal fully restores on quit.

---

## Phase 8: User Story 5 — HTML Preview (Priority: P4)

**Goal**: `wlog -a` generates `worklog.html` and opens it in the system browser (Edge on WSL).

**Independent Test**: Run `wlog -a` — browser opens with rendered HTML showing month headings, day headings, checked/unchecked checkboxes.

- [ ] T036 [US5] Implement `md_to_html()` in `src/wlog.sh` as an embedded `awk` program (from research.md R-004): handles `## ` → `<h2>`, `### ` → `<h3>`, `- [x]` → checked `<li class="done">`, `- [ ]` → unchecked `<li>`, `---` → `<hr>`, blank lines → close `<ul>`; wraps output in HTML skeleton with inline CSS; writes to `~/.local/share/wlog/worklog.html`
- [ ] T037 [US5] Implement `open_browser()` in `src/wlog.sh` (from research.md R-005): detects WSL via `uname -r | grep -qi microsoft`; on WSL uses `powershell.exe -Command "Start-Process '$(wslpath -w "$file")'"` ; on native Linux uses `xdg-open`
- [ ] T038 [US5] Wire `wlog -a` in `src/wlog.sh` main(): calls `md_to_html()` then `open_browser()`; prints path of generated HTML file to stdout

**Checkpoint**: Run `wlog -a` — browser opens, HTML renders correctly.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Error handling hardening, `NO_COLOR` support validation, install script completeness.

- [ ] T039 Add `wlog` first-run bootstrap in `src/wlog.sh` `load_config()`: if `$WLOG_FILE` does not exist, create parent directories and seed the file with the current month section + today's day heading
- [ ] T040 [P] Harden all write operations: verify `flock` acquisition with `-w 5` timeout; on timeout print `wlog: could not acquire log file lock (timeout 5s)` to stderr and exit 2
- [ ] T041 [P] Validate `NO_COLOR` suppression: add check in `load_theme()` — if `NO_COLOR` is set and non-empty, assign empty string to all `COLOR_*` vars after sourcing theme
- [ ] T042 [P] Verify `wlog -h` output matches contracts/cli-schema.md help section exactly; update if any commands added during implementation
- [ ] T043 Update `src/install.sh` to verify bash 4+ is available on PATH; print a warning (not error) if version < 5
- [ ] T044 [P] Manual smoke test: run through all commands in `quickstart.md` sequentially from a clean install; confirm all work end-to-end

**Checkpoint**: All phases complete. `wlog -h` shows correct help. `NO_COLOR=1 wlog` shows no color codes.

---

## Dependencies

```
Phase 1 (Setup)
    └── Phase 2 (Foundational) ← MUST complete before any user story
            ├── Phase 3 (US1 - View) ← MVP; can test independently after Phase 2
            ├── Phase 4 (US4 - Relative dates) ← depends on Phase 2 + Phase 3 print_day()
            ├── Phase 5 (US2 - Add entry) ← depends on Phase 2 append_entry()
            │       └── Phase 6 (US2 - Undo) ← depends on Phase 5 append_entry() + .last_entry
            ├── Phase 7 (US3 - TUI calendar) ← depends on Phase 2 + Phase 5 toggle/remove
            └── Phase 8 (US5 - HTML) ← depends on Phase 2 (log file) only
Phase 9 (Polish) ← depends on all phases complete
```

## Parallel Execution Examples

**After Phase 2 completes**, these phases can proceed in parallel:
- Phase 3 (US1) + Phase 4 (US4) — both are read-only, share `print_day()`
- Phase 8 (US5) — fully independent of TUI work

**Within phases**, tasks marked `[P]` can run in parallel:
- T002 + T003 + T004 (Phase 1 — separate files)
- T016 + T017 + T018 (Phase 3 — separate flags/tests)
- T019 + T022 + T023 (Phase 4 — separate flags)
- T026 (Phase 5 — test separate from implementation)
- T036 + T037 (Phase 8 — separate functions)
- T040 + T041 + T042 + T044 (Phase 9 — separate concerns)

## Implementation Strategy

**MVP scope** (Phases 1–4): Implement setup, foundational helpers, and US1+US4 read path first. This delivers a working `wlog`, `wlog -y`, `wlog -p N` before any TUI work begins — immediately replacing the old VS Code workflow.

**Increment 2** (Phases 5–6): Add `wlog +` write path and `--undo`. Now the tool is fully self-contained for daily use.

**Increment 3** (Phase 7): TUI calendar view — the most complex piece; implement last when all file I/O primitives are proven.

**Increment 4** (Phases 8–9): HTML preview and polish. Can be developed any time after Phase 2.
