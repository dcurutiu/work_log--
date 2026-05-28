---

description: "Task list for Manual Edit of Log File"
---

# Tasks: Manual Edit of Log File

**Input**: Design documents from `/specs/002-manual-edit-md/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli.md, quickstart.md

**Tests**: Not requested in spec — no automated test tasks generated. Manual verification per quickstart.md.

**Organization**: Tasks grouped by user story (US1 P1, US2 P2, US3 P2) so each story is independently testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files or independent edits, no dependency on prior incomplete tasks)
- **[Story]**: US1, US2, US3
- All paths are relative to repo root `/home/dcurutiu/joaca/work_log++`

## Path Conventions

Single-project bash CLI. All implementation lives in `src/wlog.sh`. No new files in `src/` (per plan.md Structure Decision).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No new infrastructure needed. The feature is a localized addition to an existing CLI script.

- [X] T001 Confirm branch `002-manual-edit-md` is checked out and working tree is clean in [src/wlog.sh](src/wlog.sh)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add the editor-resolution helper that all three user stories depend on.

**⚠️ CRITICAL**: US1, US2, US3 cannot be completed until T002 is done.

- [X] T002 Add `resolve_editor()` function to [src/wlog.sh](src/wlog.sh) implementing the precedence chain from contracts/cli.md: (1) `WLOG_EDITOR` env/config var if its first token resolves via `command -v`; (2) `code` if `command -v code` succeeds; (3) `nano` if `command -v nano` succeeds; (4) print the actionable error from contracts/cli.md to stderr and `return 2`. On success, echo the resolved command line to stdout. Place the function near the other helpers, before `cmd_help`.

**Checkpoint**: Foundation ready — user stories can now be implemented.

---

## Phase 3: User Story 1 - Open the worklog in my editor (Priority: P1) 🎯 MVP

**Goal**: Running `wlog -m` opens the existing worklog file in the user's configured/auto-detected editor and forwards the editor's exit code.

**Independent Test**: With VS Code installed and no `WLOG_EDITOR` set, run `wlog -m`; verify VS Code opens with `~/.local/share/wlog/worklog.md` and that `echo $?` after the editor exits matches the editor's exit code.

- [X] T003 [US1] Add `cmd_edit()` function to [src/wlog.sh](src/wlog.sh) that calls `resolve_editor` (capturing its output), and on success runs `exec $editor_cmd "$WLOG_FILE"` (unquoted `$editor_cmd` for word-splitting; quoted `$WLOG_FILE` for the path). On resolver failure, propagate the non-zero exit code via `exit $rc`.
- [X] T004 [US1] Add the `"-m")` case arm to the `main()` dispatch `case "$cmd"` block in [src/wlog.sh](src/wlog.sh), calling `cmd_edit`. Place it between `"-a")` and `"--undo")` to match the documentation order in `cmd_help`.

**Checkpoint**: `wlog -m` works end-to-end with `code` (or `nano` fallback). MVP delivered.

---

## Phase 4: User Story 2 - Automatic editor selection with sensible default (Priority: P2)

**Goal**: When no `WLOG_EDITOR` is configured, the CLI auto-detects `code` first, then `nano`, and shows a clear error if neither exists.

**Independent Test**: (a) With `code` on PATH and no `WLOG_EDITOR`, `wlog -m` opens VS Code. (b) With `code` removed from PATH but `nano` present, `wlog -m` opens nano. (c) With neither on PATH and no `WLOG_EDITOR`, `wlog -m` exits 2 and prints the FR-003 error message.

- [X] T005 [US2] Verify (manually, per quickstart.md §1 and §"Smoke test") that the auto-detection branch of `resolve_editor` in [src/wlog.sh](src/wlog.sh) chooses `code` over `nano`, falls back to `nano` when `code` is absent, and produces the contracts/cli.md error string when neither is found. No code change expected — `resolve_editor` from T002 already implements this; if the manual check uncovers a bug, fix it in [src/wlog.sh](src/wlog.sh) `resolve_editor`.

**Checkpoint**: Auto-detection and missing-editor error path verified.

---

## Phase 5: User Story 3 - Configure a preferred editor (Priority: P2)

**Goal**: Users can pin their preferred editor (including flags) by setting `WLOG_EDITOR` either as an env var or in `~/.config/wlog/config.sh`.

**Independent Test**: (a) `WLOG_EDITOR="vim +$" wlog -m` runs `vim +$ <worklog-path>`. (b) Adding `WLOG_EDITOR="code -w"` to `~/.config/wlog/config.sh` makes `wlog -m` invoke `code -w <worklog-path>`. (c) Both `WLOG_EDITOR` env var set AND config-file value set → env var wins.

- [X] T006 [US3] Confirm in [src/wlog.sh](src/wlog.sh) `load_config()` that the existing pattern preserves env-var precedence over config-file `WLOG_EDITOR` (env var set before sourcing → re-assert with `${WLOG_EDITOR:-}` after sourcing — or rely on the fact that env wins because `WLOG_EDITOR=...` in the config file only assigns when there is no existing env value if written as `: "${WLOG_EDITOR:=...}"`). If the precedence is wrong, add `WLOG_EDITOR="${_WLOG_EDITOR_ENV_SAVED:-${WLOG_EDITOR:-}}"`-style guarding similar to the existing `WLOG_FILE` / `WLOG_THEME` lines, so env wins.
- [X] T007 [US3] Run the three manual scenarios from quickstart.md §2 and §3 to verify env-var override, config-file override, and the env-beats-config precedence.

**Checkpoint**: Per-user and per-invocation editor configuration verified.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T008 [P] Update the `cmd_help` heredoc in [src/wlog.sh](src/wlog.sh) to add `wlog -m              Open the worklog file in your editor` under the existing command list (placed between `-a` and `--undo` to match dispatch order) and add `WLOG_EDITOR       Editor command (default: code if present, else nano)` to the Config section.
- [X] T009 [P] Run `bash -n src/wlog.sh` to syntax-check and (if available) `shellcheck src/wlog.sh` to lint the additions.
- [X] T010 Manually walk through every example in [specs/002-manual-edit-md/quickstart.md](specs/002-manual-edit-md/quickstart.md) and the failure-mode example from [specs/002-manual-edit-md/contracts/cli.md](specs/002-manual-edit-md/contracts/cli.md) to confirm SC-001..SC-004 from spec.md are met.

---

## Dependencies

```
T001 ──► T002 ──► T003 ──► T004 ──► (US1 done; MVP)
                    │
                    ├──► T005 (US2)
                    │
                    ├──► T006 ──► T007 (US3)
                    │
                    └──► T008, T009 [P] ──► T010
```

- T002 (foundational) blocks everything story-related.
- T003 must precede T004 (function defined before dispatch).
- US2 (T005) and US3 (T006–T007) are independent of US1's T003/T004 *as code*, but they consume `wlog -m` which only exists after T004 — so practically run after T004.
- T008 and T009 are independent of each other and can run in parallel.
- T010 runs last.

## Parallel Execution Examples

Within Phase 6 — Polish:

```
# Same file (wlog.sh) for T008 means it cannot run in true parallel with another
# wlog.sh edit, but T009 is read-only and can be done concurrently with T008.
T008 (edit wlog.sh help text)  ║  T009 (bash -n / shellcheck — read-only)
```

No cross-story parallelism within a single session because all stories edit the same file (`src/wlog.sh`). Story phases are nonetheless *independently testable* per quickstart scenarios.

## Implementation Strategy

**MVP scope** (stop here for the smallest useful delivery): T001 → T002 → T003 → T004. After T004, `wlog -m` works end-to-end with the auto-detected editor.

**Incremental delivery**:

1. **MVP**: T001–T004 → manually verify with `wlog -m` (US1).
2. **Polish auto-detection guarantees**: T005 (US2 verification).
3. **User configurability**: T006 → T007 (US3).
4. **Hardening**: T008 → T009 → T010.

Each increment ends in a runnable, committable state.
