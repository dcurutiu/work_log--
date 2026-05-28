# Implementation Plan: WorkLog++ CLI & TUI Activity Logger

**Branch**: `001-worklog-cli-tui` | **Date**: 2026-05-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-worklog-cli-tui/spec.md`

## Summary

A zero-dependency bash script (`wlog`) that replaces manual Markdown editing with fast CLI reads/writes and an optional TUI calendar view for daily work activities. All data stored in a single `~/.local/share/wlog/worklog.md` file using `## Month YYYY` / `### DD.MM.YYYY` / `- [ ]` structure. Implemented as `#!/usr/bin/env bash` — callable from both bash and fish. Weekend-aware date resolution: `-y`/`-t` skip Sunday/Saturday to Friday/Monday respectively. HTML preview generated inline via `awk`; browser launch via WSL-aware detection.

## Technical Context

**Language/Version**: bash 5.x (`#!/usr/bin/env bash`); callable from fish via shebang (OS executes subprocess, fish syntax not needed)  
**Primary Dependencies**: `tput`, `awk`, `sed`, `grep`, `date` (GNU), `stty`, `flock` — all standard Linux/WSL tools, zero external installs  
**Storage**: `~/.local/share/wlog/worklog.md` (log file); `~/.local/share/wlog/.last_entry` (undo state); `~/.config/wlog/theme.sh` (user theme override); `~/.local/share/wlog/worklog.html` (generated, ephemeral)  
**Testing**: Manual bash test scripts in `tests/` (no test framework needed); each test script is standalone and exits 0/1  
**Target Platform**: Linux (WSL); bash 5.x; fish 3.x as calling shell; `tput` via `ncurses` (standard on Ubuntu/Debian)  
**Project Type**: CLI tool + TUI interactive script  
**Performance Goals**: `wlog` (read path) completes in <1s; `wlog +` TUI opens in <0.5s  
**Constraints**: No external runtime dependencies; each source file ≤500 lines; total install is copy-to-PATH of 2 scripts  
**Scale/Scope**: Single user, personal machine; log file expected to grow ~5 entries/day; no network, no auth

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle                        | Gate                                        | Status      | Notes                                                                                                                                                 |
| -------------------------------- | ------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| I. Shell-First                   | Script uses only bash + standard Unix tools | ✅ PASS      | `#!/usr/bin/env bash`; deps: `tput`, `awk`, `sed`, `grep`, `date`, `stty`, `flock`                                                                    |
| II. Dual Interface               | CLI flags + TUI text input                  | ✅ PASS      | All FR-001–FR-011 covered; CLI read/write + TUI via `wlog +` and `wlog -c`                                                                            |
| III. Log File as Source of Truth | Single plain-text Markdown file             | ✅ PASS      | `worklog.md`; `## Month YYYY` + `### DD.MM.YYYY` + `- [ ]` format; hand-editable                                                                      |
| IV. Simplicity (NON-NEGOTIABLE)  | Total codebase ≤500 lines                   | ⚠️ JUSTIFIED | `-c` TUI adds ~200 lines. Resolution: split into `wlog.sh` (≤400L) + `wlog-tui.sh` (≤250L). Each file ≤500L. See Complexity Tracking.                 |
| V. Composability                 | `--json` output flag                        | ℹ️ DEFERRED  | No integration use cases in v1; `--json` omitted from spec intentionally. Log file is plain text — pipeable via `grep`/`awk` directly. Revisit in v2. |

**Pre-design gate result**: PASS (one justified exception, one deferred). Safe to proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/001-worklog-cli-tui/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── cli-schema.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
src/
├── wlog.sh              # Main entry point; all CLI commands; date logic; file I/O; undo; HTML
├── wlog-tui.sh          # Full-screen calendar TUI (-c); sourced by wlog.sh
├── theme-default.sh     # Default color variables (ships with tool, never edited by user)
└── install.sh           # Copies scripts to ~/.local/bin; creates ~/.config/wlog/; ~/.local/share/wlog/

tests/
├── unit/
│   ├── test_date_calc.sh        # resolve_workday() weekend skip logic
│   ├── test_log_parser.sh       # parse_day(), find_month_section()
│   └── test_html_converter.sh   # md_to_html() awk converter output
└── integration/
    ├── test_add_entry.sh        # wlog + flow end-to-end
    ├── test_read_entry.sh       # wlog, wlog -y, wlog -p/-f
    └── test_undo.sh             # wlog --undo removes last entry

~/.config/wlog/                  # Created by install.sh (user config dir)
├── theme.sh                     # User color overrides (optional; sourced if present)
└── config.sh                    # User config: WLOG_FILE override (optional)

~/.local/share/wlog/             # Created by install.sh (user data dir)
├── worklog.md                   # The log file (source of truth)
├── .last_entry                  # Last written entry text + date (for --undo)
└── worklog.html                 # Ephemeral; generated by wlog -a; overwritten each run
```

**Structure Decision**: Single-project layout. Two source scripts (`wlog.sh` + `wlog-tui.sh`) keep each file under 500 lines while maintaining a clean separation between core CLI logic and the heavier TUI calendar rendering. The install script copies both to `~/.local/bin/`. No build step required.

## Complexity Tracking

| Violation                       | Why Needed                                                                                                             | Simpler Alternative Rejected Because                                                                                                                        |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Two source files instead of one | `-c` TUI calendar view adds ~200 lines of `stty`/`tput` state management, key-read loop, and three-column render logic | Single file would exceed 500-line cap; splitting on a clean boundary (core vs TUI) is architecturally sound and still installs as two files via one command |

## Post-Design Constitution Check

*Re-evaluated after Phase 1 design artifacts (data-model.md, contracts/cli-schema.md, quickstart.md).*

| Principle                        | Gate                                               | Status | Notes                                                                                                                     |
| -------------------------------- | -------------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------- |
| I. Shell-First                   | No external runtime deps                           | ✅ PASS | `wlog.sh` + `wlog-tui.sh`; deps confirmed: `tput`, `awk`, `sed`, `grep`, `date`, `stty`, `flock` — all standard Linux/WSL |
| II. Dual Interface               | CLI flags + TUI                                    | ✅ PASS | Full CLI schema defined in contracts/cli-schema.md; TUI contracts for `wlog +` and `wlog -c` fully specified              |
| III. Log File as Source of Truth | Single plain-text file; hand-editable at all times | ✅ PASS | All write ops use atomic `awk` rewrite → temp → `mv`; file remains valid Markdown after every operation                   |
| IV. Simplicity                   | Each source file ≤500 lines                        | ✅ PASS | `wlog.sh` estimated ~380L; `wlog-tui.sh` estimated ~220L; `install.sh` ~40L; `theme-default.sh` ~20L                      |
| V. Composability                 | Pipeable CLI output                                | ✅ PASS | `[ ! -t 1 ]` check suppresses color when piped; output format is grep-friendly; `NO_COLOR` env var supported              |

**Post-design gate result**: ALL PASS. Proceed to `/speckit.tasks`.
