# Feature Specification: Manual Edit of Log File

**Feature Branch**: `002-manual-edit-md`
**Created**: 2026-05-28
**Status**: Draft
**Input**: User description: "i want to be able to manually edit the .md log. using -m option. if possible, use 'code' (to open it in vs code). otherwise, use nano. anyway, the 'editor' can be configurable (in the sh config file or whatever there should be a path or command to be run to open the editor)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open the worklog in my editor (Priority: P1)

As a worklog user, I want to open the raw Markdown log in a text editor with a single command so I can make freeform edits (fix typos, reorder entries, add notes the CLI doesn't support) without manually navigating to the file path.

**Why this priority**: This is the entire feature. Without it, users cannot manually edit the log at all from the CLI. Everything else (configuration, fallback) only matters because this base behavior works.

**Independent Test**: Run `wlog -m`; verify that an editor opens with the worklog file (`~/.local/share/wlog/worklog.md` by default) loaded; make a change, save, and quit; verify the change is present in the file afterwards.

**Acceptance Scenarios**:

1. **Given** the user has a populated worklog at the default path, **When** they run `wlog -m`, **Then** an editor opens with that file loaded and the cursor positioned so the user can edit it.
2. **Given** the editor is open, **When** the user saves the file and exits the editor, **Then** the change is persisted in the worklog and subsequent `wlog` invocations reflect the edited content.
3. **Given** the user exits the editor without saving, **When** the editor closes, **Then** the worklog file is unchanged.

---

### User Story 2 - Automatic editor selection with sensible default (Priority: P2)

As a user who hasn't configured anything, I want `wlog -m` to "just work" with the editor most likely to be on my machine, preferring VS Code if available and falling back to `nano` otherwise.

**Why this priority**: Out-of-the-box usability. Without auto-detection, every new user must configure something before the feature works, which makes it feel broken.

**Independent Test**: On a system where `code` is on `PATH` and no configuration exists, `wlog -m` opens VS Code with the file. On a system where `code` is not available, `wlog -m` opens `nano`.

**Acceptance Scenarios**:

1. **Given** no editor is configured and `code` is available on `PATH`, **When** the user runs `wlog -m`, **Then** VS Code opens the worklog file.
2. **Given** no editor is configured and `code` is NOT available but `nano` is, **When** the user runs `wlog -m`, **Then** `nano` opens the worklog file.
3. **Given** neither `code` nor `nano` is available on `PATH` and no editor is configured, **When** the user runs `wlog -m`, **Then** a clear error message is shown explaining that no editor was found and how to configure one, and the command exits with a non-zero status.

---

### User Story 3 - Configure a preferred editor (Priority: P2)

As a power user, I want to set my own editor (e.g., `vim`, `hx`, `nvim`, `subl -w`, or a custom script) once in a config file and have `wlog -m` always use it, overriding auto-detection.

**Why this priority**: Critical for users whose preferred editor is not VS Code or nano. Without it, the feature is unusable for that group. Slightly lower than P1 because the default behavior covers the most common case.

**Independent Test**: Set the editor in the wlog config file to a known command (e.g., `nano`), then run `wlog -m` on a machine where `code` is also available; verify the configured editor (nano) opens, not VS Code.

**Acceptance Scenarios**:

1. **Given** the user has set an editor command in `~/.config/wlog/config.sh`, **When** they run `wlog -m`, **Then** that command is invoked with the worklog path as its argument and auto-detection is skipped.
2. **Given** the configured editor command does not exist on `PATH`, **When** the user runs `wlog -m`, **Then** a clear error message names the missing command and the worklog file is not modified.
3. **Given** the `WLOG_EDITOR` environment variable is set, **When** the user runs `wlog -m`, **Then** that value takes precedence over the config file value.

---

### Edge Cases

- What happens when the worklog file does not yet exist? It should be created (using the existing first-run bootstrap) before the editor is launched, so the user opens a valid initialized file rather than an empty buffer.
- What happens when the configured editor command contains arguments (e.g., `code -w` or `subl --wait`)? The configured value is treated as a command line; the file path is appended as the last argument.
- What happens when the editor is asynchronous and returns immediately (the default behavior of `code` without `-w`)? The user is responsible for choosing a "wait" flag if they need synchronous editing; documentation will mention this for `code`.
- What happens when another `wlog` invocation is writing to the file (via the existing lock) at the moment the editor is launched? The editor opens regardless — it reads the file directly, and the existing file-lock protects only the awk-rewrite paths. Users who edit manually while another `wlog` write is in flight may encounter a last-writer-wins race; this is accepted because manual editing is interactive and rare.
- What happens when the user is on a remote SSH session with no VS Code remote? Auto-detection finds `code` only if it's on `PATH`; otherwise nano is used.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The CLI MUST accept a `-m` option that opens the worklog Markdown file in a text editor.
- **FR-002**: The CLI MUST resolve the editor to use in this order: (1) `WLOG_EDITOR` environment variable, (2) `editor` setting in `~/.config/wlog/config.sh` (or equivalent config-file mechanism), (3) `code` if available on `PATH`, (4) `nano` if available on `PATH`.
- **FR-003**: When no editor can be resolved, the CLI MUST exit with a non-zero status and print a clear error message that names the variable and config key the user can set to fix it.
- **FR-004**: The CLI MUST launch the resolved editor with the absolute path of the worklog file as the final argument, so arbitrary command-line flags configured by the user are preserved (e.g., `code -w` or `vim +$`).
- **FR-005**: The CLI MUST ensure the worklog file exists before launching the editor; if missing, it MUST be created using the existing first-run bootstrap.
- **FR-006**: The CLI MUST exit with the editor process's exit code so scripting users can detect editor failures.
- **FR-007**: The `wlog -h` help output MUST document the `-m` option and the `WLOG_EDITOR` variable / `editor` config key.

### Key Entities

- **Editor command**: A shell command line (e.g., `code`, `code -w`, `nano`, `vim +`) that, when invoked with the log file path appended, will open the log for editing. May come from the environment, the config file, or auto-detection.
- **Worklog file**: The existing Markdown file at `$WLOG_FILE` (default `~/.local/share/wlog/worklog.md`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user with VS Code installed can open the worklog for editing in under 2 seconds from typing `wlog -m` to seeing the file in their editor, with zero configuration.
- **SC-002**: 100% of saves made in the editor are visible to subsequent `wlog` invocations without requiring any sync step.
- **SC-003**: When no editor can be found, the user can resolve the failure to a working state in a single configuration step (one line in `config.sh` or one `export WLOG_EDITOR=...`) without consulting documentation outside `wlog -h`.
- **SC-004**: Users who configure an editor with required flags (e.g., `code -w`) experience the same behavior as the default, with the file path correctly appended.

## Assumptions

- The user's shell environment has `command -v` (POSIX) available to detect the presence of `code` and `nano`. This is true for bash, fish, and any POSIX-compliant shell.
- The user's editor accepts the file path as the last positional argument. This is true for virtually all common editors (`code`, `nano`, `vim`, `emacs`, `hx`, `subl`).
- Manual edits preserve the existing Markdown structure (`## Month YYYY`, `### DD.MM.YYYY`, `- [ ]` / `- [x]` lines). The CLI does not validate or repair the file after manual edits; users are trusted to keep the format intact. (A future feature could add a `wlog --lint` validator if needed.)
- The existing file lock (`flock` on `WLOG_LOCK`) is not held during manual editing. Concurrent automated `wlog` writes during manual editing are rare enough that last-writer-wins is acceptable.
- Configuration uses the existing `~/.config/wlog/config.sh` mechanism (sourced as shell), introducing one new variable (`WLOG_EDITOR`). No new config-file format is needed.
