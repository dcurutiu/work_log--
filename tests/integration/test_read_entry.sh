#!/usr/bin/env bash
# Integration tests: read path
# Tests: wlog (default), wlog -y, wlog -t, wlog -p N, wlog -f N
# Exit 0 = all pass
set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WLOG_SH="${SCRIPT_DIR}/../../src/wlog.sh"

# Use an isolated temp log file
export WLOG_FILE
WLOG_FILE=$(mktemp)
export NO_COLOR=1

cleanup() { rm -f "$WLOG_FILE"; }
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

# ---------------------------------------------------------------------------
# Seed helper: write known entries directly to WLOG_FILE
seed_entry() {
    local date_log="$1"  # DD.MM.YYYY
    local date_iso="${date_log:6:4}-${date_log:3:2}-${date_log:0:2}"
    local month_name
    month_name=$(date -d "$date_iso" +"%B %Y")

    # Ensure month section exists
    if ! grep -qF "## ${month_name}" "$WLOG_FILE" 2>/dev/null; then
        printf "\n## %s\n\n" "$month_name" >> "$WLOG_FILE"
    fi
    # Ensure day section exists
    if ! grep -qF "### ${date_log}" "$WLOG_FILE" 2>/dev/null; then
        printf "### %s\n\n" "$date_log" >> "$WLOG_FILE"
    fi
    # Append entry
    shift
    for entry in "$@"; do
        printf -- "- [ ] %s\n" "$entry" >> "$WLOG_FILE"
    done
    printf "\n" >> "$WLOG_FILE"
}

mark_done() {
    local date_log="$1" text="$2"
    sed -i "s/- \[ \] ${text}/- [x] ${text}/" "$WLOG_FILE"
}

# ---------------------------------------------------------------------------
today_iso=$(date +%Y-%m-%d)
today_log="${today_iso:8:2}.${today_iso:5:2}.${today_iso:0:4}"

yest_iso=$(date -d "$today_iso -1 day" +%Y-%m-%d)
yest_log="${yest_iso:8:2}.${yest_iso:5:2}.${yest_iso:0:4}"

p3_iso=$(date -d "$today_iso -3 days" +%Y-%m-%d)
p3_log="${p3_iso:8:2}.${p3_iso:5:2}.${p3_iso:0:4}"

f2_iso=$(date -d "$today_iso +2 days" +%Y-%m-%d)
f2_log="${f2_iso:8:2}.${f2_iso:5:2}.${f2_iso:0:4}"

# Seed data
seed_entry "$today_log" "task today one" "task today two"
seed_entry "$yest_log"  "task yesterday one"
mark_done  "$today_log" "task today two"
seed_entry "$p3_log"    "task three days ago"

# ---------------------------------------------------------------------------
echo "=== wlog (default: today + workday-yesterday) ==="
out=$(bash "$WLOG_SH")
assert_contains "today heading"     "### ${today_log}" "$out"
assert_contains "today unchecked"   "- [ ] task today one" "$out"
assert_contains "today checked"     "- [x] task today two" "$out"
assert_contains "yesterday heading" "### ${yest_log}" "$out"
assert_contains "yesterday entry"   "- [ ] task yesterday one" "$out"

echo "=== wlog -y (yesterday only) ==="
out=$(bash "$WLOG_SH" -y)
assert_contains     "-y yesterday heading" "### ${yest_log}" "$out"
assert_contains     "-y yesterday entry"   "- [ ] task yesterday one" "$out"
assert_not_contains "-y no today"          "### ${today_log}" "$out"

echo "=== wlog -p 3 ==="
out=$(bash "$WLOG_SH" -p 3)
assert_contains     "-p3 heading" "### ${p3_log}" "$out"
assert_contains     "-p3 entry"   "- [ ] task three days ago" "$out"
assert_not_contains "-p3 no today" "### ${today_log}" "$out"

echo "=== wlog -f 2 ==="
out=$(bash "$WLOG_SH" -f 2)
assert_contains     "-f2 heading"  "### ${f2_log}" "$out"
assert_contains     "-f2 no entry" "(no entries)" "$out"

echo "=== wlog -t (tomorrow, workday-aware) ==="
out=$(bash "$WLOG_SH" -t)
# Just verify it prints a single date heading (content depends on date)
line_count=$(echo "$out" | grep -c "^### " || true)
if [[ "$line_count" -eq 1 ]]; then
    echo "  PASS: -t prints exactly one date section"
    PASS=$(( PASS + 1 ))
else
    echo "  FAIL: -t expected 1 date heading, got $line_count"
    FAIL=$(( FAIL + 1 ))
fi

echo "=== wlog empty date shows (no entries) ==="
out=$(bash "$WLOG_SH" -f 2)
assert_contains "empty state message" "(no entries)" "$out"

echo "=== wlog -p bad arg ==="
if bash "$WLOG_SH" -p 0 2>/dev/null; then
    echo "  FAIL: -p 0 should exit non-zero"
    FAIL=$(( FAIL + 1 ))
else
    echo "  PASS: -p 0 exits with error"
    PASS=$(( PASS + 1 ))
fi

if bash "$WLOG_SH" -p abc 2>/dev/null; then
    echo "  FAIL: -p abc should exit non-zero"
    FAIL=$(( FAIL + 1 ))
else
    echo "  PASS: -p abc exits with error"
    PASS=$(( PASS + 1 ))
fi

echo "=== wlog -h ==="
out=$(bash "$WLOG_SH" -h)
assert_contains "-h shows wlog +" "wlog +" "$out"
assert_contains "-h shows --undo" "--undo" "$out"
assert_contains "-h shows -c"     "wlog -c" "$out"

# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
