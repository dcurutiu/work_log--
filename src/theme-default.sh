#!/usr/bin/env bash
# WorkLog++ — Default color theme
# Variables are sourced by wlog.sh at startup.
# User override: ~/.config/wlog/theme.sh (same format, only variable assignments)

# Today's date heading
COLOR_TODAY="\033[1;37m"         # Bold white

# Yesterday's date heading
COLOR_YESTERDAY="\033[0;36m"     # Cyan

# Tomorrow's date heading
COLOR_TOMORROW="\033[0;35m"      # Magenta

# Checked entries  - [x]
COLOR_CHECKED="\033[0;32m"       # Green

# Unchecked entries  - [ ]
COLOR_UNCHECKED="\033[0;33m"     # Yellow

# Day headings (### DD.MM.YYYY) in CLI output
COLOR_DATE_HEADING="\033[1;34m"  # Bold blue

# Month headings (## Month YYYY) in CLI output
COLOR_MONTH_HEADING="\033[1;33m" # Bold yellow

# ANSI reset
COLOR_RESET="\033[0m"

# Selected item in -c TUI (reverse video)
COLOR_HIGHLIGHT="\033[7m"

# TUI borders and separators
COLOR_BORDER="\033[0;90m"        # Dark gray
