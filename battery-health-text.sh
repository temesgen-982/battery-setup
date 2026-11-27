#!/usr/bin/env bash
# Write a compact health line for i3status' read_file module: "health 58%"
set -u

BAT="${BAT:-/sys/class/power_supply/BAT0}"
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/battery-health"
mkdir -p "$DIR"

full=$(cat "$BAT/energy_full" 2>/dev/null || true)
design=$(cat "$BAT/energy_full_design" 2>/dev/null || true)

if [ -n "$full" ] && [ -n "$design" ] && [ "$design" != "0" ]; then
  h=$(awk -v f="$full" -v d="$design" 'BEGIN{printf "%.0f", f/d*100}')
  printf 'health %s%%\n' "$h" > "$DIR/health.txt"
fi
