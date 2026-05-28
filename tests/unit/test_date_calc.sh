#!/usr/bin/env bash
# Unit tests: date calculation helpers
# Tests: log_to_iso, iso_to_log, month_heading, resolve_workday
# Exit 0 = all pass; Exit 1 = failures
set -euo pipefail

PASS=0
FAIL=0

# Source the functions under test (load only; skip main)
# We override main() and set WLOG_FILE to a temp file so load_config/load_theme
# do not run during source.
WLOG_FILE="$(mktemp)"
WLOG_THEME="/dev/null"
NO_COLOR=1

# Temporarily replace main() to prevent execution on source
_source_wlog() {
    # Trick: source with a wrapper that no-ops main
    local wlog_src
    wlog_src="$(dirname "${BASH_SOURCE[0]}")"/../../src/wlog.sh
    # Read the file, replace the final `main "$@"` call with a no-op
    local tmpf
    tmpf=$(mktemp --suffix=.sh)
    sed 's/^main "\$@"$/: # main call disabled for unit tests/' "$wlog_src" > "$tmpf"
    # shellcheck source=/dev/null
    source "$tmpf"
    rm -f "$tmpf"
}
_source_wlog

# Cleanup
rm -f "$WLOG_FILE"

# ---------------------------------------------------------------------------
assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  PASS: $label"
        PASS=$(( PASS + 1 ))
    else
        echo "  FAIL: $label"
        echo "        expected: '$expected'"
        echo "        actual:   '$actual'"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ---------------------------------------------------------------------------
echo "=== log_to_iso ==="
assert_eq "28.05.2026" "2026-05-28" "$(log_to_iso "28.05.2026")"
assert_eq "01.01.2025" "2025-01-01" "$(log_to_iso "01.01.2025")"
assert_eq "31.12.2024" "2024-12-31" "$(log_to_iso "31.12.2024")"

echo "=== iso_to_log ==="
assert_eq "2026-05-28" "28.05.2026" "$(iso_to_log "2026-05-28")"
assert_eq "2025-01-01" "01.01.2025" "$(iso_to_log "2025-01-01")"

echo "=== month_heading ==="
assert_eq "2026-05-28" "May 2026"      "$(month_heading "2026-05-28")"
assert_eq "2026-01-01" "January 2026"  "$(month_heading "2026-01-01")"
assert_eq "2026-12-31" "December 2026" "$(month_heading "2026-12-31")"

echo "=== resolve_workday — forward (+1) ==="
# Monday + 1 → Tuesday
assert_eq "Mon+1→Tue" "2026-05-26" \
    "$(resolve_workday "2026-05-25" +1)"  # Mon 25 May → Tue 26 May
# Friday + 1 → Monday (skips weekend)
assert_eq "Fri+1→Mon" "2026-06-01" \
    "$(resolve_workday "2026-05-29" +1)"  # Fri 29 May → Mon 1 Jun
# Saturday + 1 → Monday
assert_eq "Sat+1→Mon" "2026-06-01" \
    "$(resolve_workday "2026-05-30" +1)"  # Sat 30 May → Mon 1 Jun (base+1=Sun→Mon)
# Sunday + 1 → Monday
assert_eq "Sun+1→Mon" "2026-06-01" \
    "$(resolve_workday "2026-05-31" +1)"  # Sun 31 May → Mon 1 Jun

echo "=== resolve_workday — backward (-1) ==="
# Tuesday - 1 → Monday
assert_eq "Tue-1→Mon" "2026-05-25" \
    "$(resolve_workday "2026-05-26" -1)"  # Tue 26 May → Mon 25 May
# Monday - 1 → Friday (skips weekend)
assert_eq "Mon-1→Fri" "2026-05-29" \
    "$(resolve_workday "2026-06-01" -1)"  # Mon 1 Jun → Fri 29 May
# Sunday - 1 → Friday
assert_eq "Sun-1→Fri" "2026-05-29" \
    "$(resolve_workday "2026-05-31" -1)"  # Sun 31 May → Fri 29 May (base-1=Sat→Fri)
# Saturday - 1 → Friday
assert_eq "Sat-1→Fri" "2026-05-29" \
    "$(resolve_workday "2026-05-30" -1)"  # Sat 30 May → Fri 29 May

# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
