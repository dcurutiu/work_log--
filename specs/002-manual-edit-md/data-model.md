# Phase 1 — Data Model: Manual Edit of Log File

This feature has no persistent data model of its own — it operates on the existing worklog Markdown file. The only "entities" are configuration values consumed at runtime.

## Runtime Configuration Entities

### `WLOG_EDITOR` (environment variable)

- **Type**: shell string (command line)
- **Source**: process environment
- **Precedence**: highest (overrides config file and auto-detection)
- **Lifetime**: per-invocation
- **Example values**: `"code -w"`, `"nano"`, `"vim"`, `"hx"`, `"subl --wait"`
- **Validation**: the first token (after word-splitting) MUST be resolvable on `PATH` via `command -v`. If not, `wlog -m` fails with a clear error message naming the missing command.

### `editor` (config-file key)

- **Type**: bash variable assigned in `~/.config/wlog/config.sh`
- **Source**: sourced by `load_config()`
- **Precedence**: middle (overrides auto-detection; overridden by `WLOG_EDITOR`)
- **Spelling**: assigned as `WLOG_EDITOR="..."` in the config file (single canonical variable name; no separate "editor=" key to avoid two-name confusion).
- **Example config snippet**:
  ```bash
  # ~/.config/wlog/config.sh
  WLOG_EDITOR="code -w"
  ```
- **Validation**: same as the env var — the first token must resolve via `command -v`.

### Auto-detection candidates

- **`code`** — preferred default if available
- **`nano`** — fallback default if `code` is absent
- **Detection method**: `command -v <name> &>/dev/null` returns success when the binary is on `PATH`.

## State Transitions

`cmd_edit` follows a single linear resolution pipeline, no internal state:

```
start
  → if WLOG_EDITOR set & first-token-exists → use it
  → elif (config sourced WLOG_EDITOR) & first-token-exists → use it
  → elif command -v code → use "code"
  → elif command -v nano → use "nano"
  → else → print actionable error to stderr; exit 2
  → exec $editor_cmd "$WLOG_FILE"   (replaces process)
```

(Note: the env-var case and config-file case collapse into a single check because `load_config()` already merges env-var precedence over config-file via the standard `${WLOG_EDITOR:-$config_value}` pattern. See contracts/cli.md.)

## Relationships

- **Worklog file** (`$WLOG_FILE`): read AND written by the editor. `cmd_edit` does NOT mediate I/O — it hands the path to the editor and the editor owns the file until it exits.
- **Lock file** (`$WLOG_LOCK`): NOT acquired by `cmd_edit`. See research Decision 5.
- **No new persisted files** are introduced by this feature.
