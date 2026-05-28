#!/usr/bin/env bash
# WorkLog++ Installer
# Copies scripts to ~/.local/bin and sets up config/data directories.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/wlog"
DATA_DIR="${HOME}/.local/share/wlog"

# ---------------------------------------------------------------------------
# Bash version check (T043)
# ---------------------------------------------------------------------------
bash_major="${BASH_VERSINFO[0]:-0}"
if [[ "$bash_major" -lt 4 ]]; then
    echo "WARNING: bash 4+ is required. Detected bash ${BASH_VERSION}. Please upgrade."
    exit 1
elif [[ "$bash_major" -lt 5 ]]; then
    echo "NOTE: bash 5+ is recommended. Detected bash ${BASH_VERSION}."
fi

echo "Installing WorkLog++..."

# Create directories
mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$DATA_DIR"

# Copy scripts
cp "${SCRIPT_DIR}/wlog.sh"     "${BIN_DIR}/wlog"
cp "${SCRIPT_DIR}/wlog-tui.sh" "${BIN_DIR}/wlog-tui"
chmod +x "${BIN_DIR}/wlog" "${BIN_DIR}/wlog-tui"

# Copy default theme (only if user theme does not already exist)
if [[ ! -f "${CONFIG_DIR}/theme.sh" ]]; then
    cp "${SCRIPT_DIR}/theme-default.sh" "${CONFIG_DIR}/theme.sh"
    echo "  Created default theme: ${CONFIG_DIR}/theme.sh"
else
    echo "  Existing theme preserved: ${CONFIG_DIR}/theme.sh"
fi

echo ""
echo "Installed:"
echo "  ${BIN_DIR}/wlog"
echo "  ${BIN_DIR}/wlog-tui"
echo "  ${CONFIG_DIR}/theme.sh  (color theme)"
echo "  ${DATA_DIR}/            (log file will be created on first run)"
echo ""

# PATH instructions
if echo ":${PATH}:" | grep -q ":${BIN_DIR}:"; then
    echo "✓ ${BIN_DIR} is already in your PATH."
else
    echo "Add ${BIN_DIR} to your PATH:"
    echo ""
    echo "  bash/zsh — add to ~/.bashrc or ~/.zshrc:"
    echo '    export PATH="$HOME/.local/bin:$PATH"'
    echo ""
    echo "  fish — run once:"
    echo '    fish_add_path ~/.local/bin'
    echo ""
fi

echo "Done. Try: wlog -h"
