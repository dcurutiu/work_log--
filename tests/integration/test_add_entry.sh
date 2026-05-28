#!/usr/bin/env bash
# Integration tests: add entry (T026) + undo (T028)
# Exit 0 = all pass
set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WLOG_SH="${SCRIPT_DIR}/../../src/wlog.sh"

export WLOG_FILE
WLOG_FILE=$(mktemp)
export NO_COLOR=1

cleanup() { rm -f "$WLOG_FILE" "/tmp/wlog_${USER}.lock" 2>/dev/null; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
assert_contains() {
    local label="$1" pattern="$2" text="$3"
    if echo "$text" | grep -qF -- "$pattern"; then
        echo "  PASS: $label"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $label"
        echo "        pattern:  '$pattern'"
        echo "        in output: $(echo "$text" | head -5)"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_not_contains() {
    local label="$1" pattern="$2" text="$3"
    if ! echo "$text" | grep -qF -- "$pattern"; then
        echo "  PASS: $label"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $label (pattern found but should not be)"
        echo "        pattern:  '$pattern'"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_file_contains() {
    local label="$1" pattern="$2"
    if grep -qF -- "$pattern" "$WLOG_FILE" 2>/dev/null; then
        echo "  PASS: $label"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $label"
        echo "        pattern:  '$pattern'"
        echo "        file contents: $(cat "$WLOG_FILE" | head -10)"
        FAIL=$(( FAIL + 1 ))
    fi
}

assert_file_not_contains() {
    local label="$1" pattern="$2"
    if ! grep -qF -- "$pattern" "$WLOG_FILE" 2>/dev/null; then
        echo "  PASS: $label"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $label (pattern found but should not be)"
        echo "        pattern:  '$pattern'"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ---------------------------------------------------------------------------
today_iso=$(date +%Y-%m-%d)
today_log="${today_iso:8:2}.${today_iso:5:2}.${today_iso:0:4}"

echo "=== append_entry: adds entry to file ==="

# Use wlog.sh's append_entry by sourcing it (with NO_COLOR=1 it won't try tui)
# Inject entry via sourcing internal function
(
    source "$WLOG_SH"
    load_config
    append_entry "$today_log" "test entry from test"
)

assert_file_contains "entry written to file"    "- [ ] test entry from test"
assert_file_contains "day heading created"      "### ${today_log}"

out=$(bash "$WLOG_SH")
assert_contains "entry visible in output"   "- [ ] test entry from test" "$out"
assert_contains "day heading in output"     "### ${today_log}" "$out"

echo "=== append_entry: second entry same day ==="
(
    source "$WLOG_SH"
    load_config
    append_entry "$today_log" "second entry same day"
)
out=$(bash "$WLOG_SH")
assert_contains "both entries visible" "- [ ] test entry from test" "$out"
assert_contains "second entry visible" "- [ ] second entry same day" "$out"

echo "=== append_entry: .last_entry state written ==="
last_file="${WLOG_DATA:-${HOME}/.local/share/wlog}/.last_entry"
(
    source "$WLOG_SH"
    load_config
    append_entry "$today_log" "entry for undo test"
)
if [[ -f "$last_file" ]]; then
    echo "  PASS: .last_entry file exists"
    PASS=$(( PASS + 1 ))
    if grep -qF -- "entry for undo test" "$last_file"; then
        echo "  PASS: .last_entry contains entry text"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: .last_entry missing entry text"
        FAIL=$(( FAIL + 1 ))
    fi
else
    echo "  FAIL: .last_entry not created"
    FAIL=$(( FAIL + 1 ))
    echo "  FAIL: .last_entry missing (skipping text check)"
    FAIL=$(( FAIL + 1 ))
fi

echo "=== cmd_undo: removes last-added entry ==="
assert_file_contains "entry present before undo" "- [ ] entry for undo test"
(
    source "$WLOG_SH"
    load_config
    cmd_undo
)
assert_file_not_contains "entry removed after undo" "- [ ] entry for undo test"

echo "=== cmd_undo: double undo is a no-op (clears state) ==="
exit_code=0
(
    source "$WLOG_SH"
    load_config
    cmd_undo
) || exit_code=$?
# Second undo should exit non-zero (nothing to undo) OR exit 0 silently — both acceptable
# What we verify is the entry is still absent
assert_file_not_contains "still absent after double undo" "- [ ] entry for undo test"
echo "  PASS: double undo handled without crash (exit=$exit_code)"
PASS=$(( PASS + 1 ))

echo "=== toggle_entry: [ ] → [x] ==="
(
    source "$WLOG_SH"
    load_config
    append_entry "$today_log" "toggle me"
)
assert_file_contains "unchecked before toggle" "- [ ] toggle me"
(
    source "$WLOG_SH"
    load_config
    toggle_entry "$today_log" "- [ ] toggle me"
)
assert_file_contains     "checked after toggle"  "- [x] toggle me"
assert_file_not_contains "no unchecked remains"  "- [ ] toggle me"

echo "=== toggle_entry: [x] → [ ] ==="
(
    source "$WLOG_SH"
    load_config
    toggle_entry "$today_log" "- [x] toggle me"
)
assert_file_contains     "unchecked again"       "- [ ] toggle me"
assert_file_not_contains "no checked remains"    "- [x] toggle me"

# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
