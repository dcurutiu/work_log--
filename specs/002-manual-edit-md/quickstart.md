# Quickstart — Manual Edit of Log File

## Prerequisites

- `wlog` installed (run `bash src/install.sh` from the repo root).
- Either `code` (VS Code) or `nano` on `PATH`, OR a preferred editor of your choice.

## Try it

### 1. Open the worklog with the default editor

```bash
wlog -m
```

- On a system with VS Code installed (`code` on `PATH`), this opens `~/.local/share/wlog/worklog.md` in VS Code.
- Otherwise it opens the file in `nano`.

Make a change, save, exit. Verify it stuck:

```bash
wlog
```

You should see the edited content.

### 2. Use your own editor (one-shot)

```bash
WLOG_EDITOR=vim wlog -m
```

Replace `vim` with `nvim`, `hx`, `emacs -nw`, `subl --wait`, etc. The first token must be on `PATH`.

### 3. Configure your editor permanently

Create or edit `~/.config/wlog/config.sh`:

```bash
mkdir -p ~/.config/wlog
cat >> ~/.config/wlog/config.sh <<'EOF'
WLOG_EDITOR="code -w"
EOF
```

Now `wlog -m` always uses `code -w` (the `-w` flag makes VS Code block until you close the file, which is useful in scripts).

### 4. Pass flags through to your editor

Anything before the file path is preserved. For example, to open the file at end-of-file in vim:

```bash
WLOG_EDITOR="vim +$" wlog -m
```

The actual command run is `vim +$ ~/.local/share/wlog/worklog.md`.

### 5. Inspect the help

```bash
wlog -h
```

Confirm that `-m` and `WLOG_EDITOR` appear in the output.

## Smoke test (no editor installed)

To verify the error path:

```bash
PATH=/usr/bin wlog -m
# Expected: error message naming WLOG_EDITOR, exit code 2.
```

## Troubleshooting

| Symptom                                          | Likely Cause                                                                        | Fix                                                                           |
| ------------------------------------------------ | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `wlog: no editor available. ...`                 | Neither `code` nor `nano` on `PATH`, no `WLOG_EDITOR` set                           | `export WLOG_EDITOR=<your-editor>` or install one                             |
| `wlog: configured editor 'X' not found on PATH.` | `WLOG_EDITOR` first token misspelled or binary not installed                        | Correct the value or install the binary                                       |
| Editor opens an empty buffer                     | The worklog file didn't exist; bootstrap just created a minimal one. Save normally. | None — this is expected on first run                                          |
| Concurrent `wlog +` writes overwrite my edits    | You edited while another shell ran `wlog +`                                         | Avoid concurrent automated writes during manual edits (documented limitation) |
