# CLI Contract: `wlog -m`

## Synopsis

```
wlog -m
```

## Description

Opens the worklog Markdown file in a text editor for freeform manual editing. The editor is selected from (in order of precedence):

1. `WLOG_EDITOR` environment variable
2. `WLOG_EDITOR` set in `~/.config/wlog/config.sh`
3. `code` (VS Code) if available on `PATH`
4. `nano` if available on `PATH`

If none of these resolves to an executable on `PATH`, the command fails.

## Arguments

None. The `-m` flag takes no operand.

## Behavior

| Condition                                                   | Behavior                                                          |
| ----------------------------------------------------------- | ----------------------------------------------------------------- |
| `WLOG_EDITOR` is set and its first token resolves on `PATH` | The editor is launched as `<editor_cmd> <WLOG_FILE>`.             |
| `WLOG_EDITOR` is unset, `code` is on `PATH`                 | `code "$WLOG_FILE"` is launched.                                  |
| `WLOG_EDITOR` is unset, `code` absent, `nano` on `PATH`     | `nano "$WLOG_FILE"` is launched.                                  |
| Neither `code` nor `nano` available, no `WLOG_EDITOR`       | Exit non-zero (code 2), print actionable error to stderr.         |
| `WLOG_EDITOR` set but first token NOT on `PATH`             | Exit non-zero (code 2), print error naming the missing command.   |
| Worklog file does not exist                                 | Created via existing first-run bootstrap before launching editor. |

## Exit Codes

| Code                    | Meaning                                                                                 |
| ----------------------- | --------------------------------------------------------------------------------------- |
| `0`                     | Editor exited successfully (also the contract: exit code is forwarded from the editor). |
| Editor's code (nonzero) | Forwarded as-is.                                                                        |
| `2`                     | `wlog` could not resolve any editor, or the configured editor command is not on `PATH`. |
| `1`                     | Reserved for unknown flag (matches existing `wlog` convention for other invalid args).  |

## stdout / stderr / stdin

- The editor inherits the terminal directly (`stdin`, `stdout`, `stderr`).
- `wlog -m` itself writes no output on the success path.
- On failure to resolve an editor, the error message is written to `stderr` in this form:

  ```
  wlog: no editor available. Set WLOG_EDITOR (env var or in ~/.config/wlog/config.sh), or install 'code' or 'nano'.
  ```

  When a configured editor is missing:

  ```
  wlog: configured editor 'subl' not found on PATH. Update WLOG_EDITOR.
  ```

## Side Effects

- The worklog file (`$WLOG_FILE`) may be modified by the user inside the editor. Whether changes are saved is entirely up to the user.
- The `~/.local/share/wlog/.last_entry` undo-state file is NOT touched. (`wlog --undo` after a manual edit will still refer to the last entry created by `wlog +`.)
- No lock file is acquired (see plan/research Decision 5).

## Help Text Contract

`wlog -h` MUST include lines documenting:

- `wlog -m              Open the worklog file in your editor`
- `WLOG_EDITOR       Editor command (default: code if present, else nano)`

## Examples

### Default behavior with VS Code installed

```
$ wlog -m
# (VS Code window opens with worklog.md)
$ echo $?
0
```

### Override with env var

```
$ WLOG_EDITOR="vim +$" wlog -m
# (vim opens worklog.md at end of file)
```

### Persistent config

```
$ cat ~/.config/wlog/config.sh
WLOG_EDITOR="code -w"

$ wlog -m
# (VS Code opens; -w makes 'code' wait until window closes)
```

### Failure mode — no editor available

```
$ PATH=/usr/bin wlog -m   # hypothetical PATH without code or nano
wlog: no editor available. Set WLOG_EDITOR (env var or in ~/.config/wlog/config.sh), or install 'code' or 'nano'.
$ echo $?
2
```
