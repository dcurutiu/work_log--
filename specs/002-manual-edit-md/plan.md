# Implementation Plan: Manual Edit of Log File

**Branch**: `002-manual-edit-md` | **Date**: 2026-05-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-manual-edit-md/spec.md`

## Summary

Add a `wlog -m` command that opens the worklog Markdown file in a text editor. The editor is resolved in this order: `WLOG_EDITOR` env var → `editor` config key in `~/.config/wlog/config.sh` → auto-detect `code` → auto-detect `nano` → error. The configured value is treated as a command line; the worklog path is appended as the final argument. The CLI exits with the editor's exit code. Implementation is a small addition to `src/wlog.sh`.

## Technical Context

**Language/Version**: bash 5.x (existing project baseline)
**Primary Dependencies**: coreutils (`command -v`, `mkdir`), user-provided editor binary on `PATH`
**Storage**: existing `~/.local/share/wlog/worklog.md` (no new files)
**Testing**: bash smoke tests; manual verification via `wlog -m`
**Target Platform**: Linux/WSL (existing baseline); portable to any bash 4+ environment
**Project Type**: CLI tool (single-project layout)
**Performance Goals**: < 100ms from `wlog -m` to editor process spawn
**Constraints**: must NOT hold the existing `flock` lock during editing; must NOT introduce a new config-file format
**Scale/Scope**: ~30 lines added to `src/wlog.sh`; help text updated; no new files in `src/`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution (`.specify/memory/constitution.md`) is the unfilled template — no project-specific principles are defined. No gates to check; no violations possible. This matches the precedent set by feature `001-worklog-cli-tui`.

**Result**: PASS (vacuously).

## Project Structure

### Documentation (this feature)

```text
specs/002-manual-edit-md/
├── plan.md              # This file
├── spec.md              # Feature spec
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── cli.md           # CLI contract for the -m subcommand
└── checklists/
    └── requirements.md  # From /speckit.specify
```

### Source Code (repository root)

```text
src/
├── wlog.sh              # MODIFIED: add resolve_editor(), cmd_edit(), -m case, help text
├── wlog-tui.sh          # untouched
├── theme-default.sh     # untouched
└── install.sh           # untouched (install copies wlog.sh as-is)
```

**Structure Decision**: Single-project bash CLI. The feature is a localized addition to `src/wlog.sh`. No new top-level directories. The existing `~/.config/wlog/config.sh` mechanism is reused (already sourced by `load_config`); a new `WLOG_EDITOR` shell variable joins the existing `WLOG_FILE` and `WLOG_THEME`.

## Complexity Tracking

No constitution gates to violate.

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --------- | ---------- | ------------------------------------ |
| _(none)_  | —          | —                                    |
