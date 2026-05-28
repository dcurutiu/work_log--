# Phase 0 — Research: Manual Edit of Log File

## Unknowns from Technical Context

None of the spec items were marked `NEEDS CLARIFICATION`. The technical context is fully determined by existing project choices (bash, single CLI, sourced config file). The only research items are best-practice questions for the new code.

---

## Decision 1 — How to invoke the editor

**Decision**: Use bash word-splitting on the resolved editor string, append the worklog path as the final positional argument, then `exec` (replace current process) so the editor inherits stdio and the exit status is the editor's.

**Rationale**:
- Word-splitting (`$editor_cmd "$WLOG_FILE"` without quoting `$editor_cmd`) lets users configure `code -w`, `vim +$`, etc., without us reimplementing a shell parser.
- `exec` makes the editor's exit code automatically become `wlog`'s exit code (satisfies FR-006) and avoids leaving a defunct bash process while the user is editing.
- Interactive editors (`nano`, `vim`) need a real TTY — `exec` preserves the parent's stdin/stdout/stderr unchanged.

**Alternatives considered**:
- `eval "$editor_cmd \"$WLOG_FILE\""` — rejected: harder to reason about quoting and a needless `eval` security smell.
- `bash -c "$editor_cmd \"$WLOG_FILE\""` — rejected: adds a subshell, breaks `exec` semantics, and the editor's TTY handling becomes fragile.
- Hard-coded `code`/`nano` invocation only (no config) — rejected: spec FR-002 requires user-configurable command.

---

## Decision 2 — Editor resolution order

**Decision**: `WLOG_EDITOR` env var > `editor` config key in `~/.config/wlog/config.sh` > `code` if on `PATH` > `nano` if on `PATH` > error.

**Rationale**:
- Env-var-first matches the precedent already established for `WLOG_FILE` and `WLOG_THEME` (see `load_config` in `src/wlog.sh`).
- VS Code preference matches the user's explicit request ("if possible, use 'code'").
- `nano` is the universally-available fallback (POSIX-ish, present on virtually every Linux/WSL install).
- Failing with a clear actionable message (FR-003) is better than silently picking `vi` on systems that have it; we don't want to surprise users with an unfamiliar modal editor.

**Alternatives considered**:
- Use `$EDITOR`/`$VISUAL` like `git` does — rejected (for now): the user explicitly asked for a `wlog`-specific configuration key. We can layer `$EDITOR` in as a future enhancement if requested.
- Pick the first of many editors (e.g., `code`, `subl`, `hx`, `nvim`, `vim`, `nano`) — rejected: too magical, surprising on systems where multiple are installed. Spec says "code, then nano".

---

## Decision 3 — `command -v` for detection

**Decision**: Use `command -v code &>/dev/null` and `command -v nano &>/dev/null` to detect availability.

**Rationale**:
- POSIX-standard, present in bash, fish, sh, zsh, dash.
- Faster than `which` (no subprocess fork) and doesn't depend on the `which` binary being installed.
- Returns the resolved path on success, suitable as a positive boolean check.

**Alternatives considered**:
- `which code` — slower (subprocess) and not universally available.
- `type code` — works but produces output to stderr/stdout that must be suppressed; `command -v` is the bash-idiomatic choice.

---

## Decision 4 — Ensure file exists before editor launch

**Decision**: Reuse the existing first-run bootstrap in `load_config()`. By the time `cmd_edit` is called, `load_config` has already run (it's invoked unconditionally at the top of `main()`), so the file is guaranteed to exist.

**Rationale**:
- Zero new code: the bootstrap is already a side effect of `load_config()`.
- Satisfies FR-005 (file must exist before editor launches).
- No race window: the bootstrap runs before any command dispatch.

**Alternatives considered**:
- Add a separate `touch "$WLOG_FILE"` in `cmd_edit` — rejected as duplication.
- Open the editor on the missing file and let the user save to create it — rejected: violates FR-005 and is confusing for new users who expect a populated log to exist.

---

## Decision 5 — Locking during manual edit

**Decision**: Do NOT acquire the `WLOG_LOCK` flock when launching the editor. Manual editing is interactive; holding a lock for minutes or hours would block all automated `wlog +`/toggle operations.

**Rationale**:
- The existing lock guards short awk-rewrite critical sections (milliseconds). Extending it to cover interactive editing would be a usability regression for anyone running `wlog` from another shell.
- Manual editing is by definition a deliberate user action; users accept that running `wlog +` from another shell while a manual edit is in flight may produce a last-writer-wins outcome.
- The spec explicitly accepts this trade-off (Assumptions section).

**Alternatives considered**:
- Acquire the lock until the editor exits — rejected: noticeable freezing for any concurrent `wlog` invocation.
- Take a snapshot, lock during the `mv` of edited contents back — rejected: would require us to copy the file out, run the editor on a tempfile, then merge back. Adds complexity and a new failure mode (concurrent edit conflict resolution).

---

## Best Practices Consolidated

- **Word-split, don't `eval`**: store user editor command as a plain string variable, then use unquoted expansion at the call site.
- **`exec` for terminal handover**: replaces the shell process so the editor owns the TTY cleanly.
- **`command -v` for binary detection**: bash-idiomatic, fast, POSIX-portable.
- **Reuse existing bootstrap**: don't duplicate the first-run file-creation logic.
- **Document escape-hatches in help**: users should see `WLOG_EDITOR` mentioned in `wlog -h` so they can self-serve when auto-detection picks the "wrong" editor.

All NEEDS CLARIFICATION items: **none** (spec was fully determined).
