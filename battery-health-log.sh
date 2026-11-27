#!/usr/bin/env bash
# Weekly battery-health logger — ThinkPad T590 (BAT0)
# Appends one CSV row per run to ~/.local/share/battery-health/health.csv
set -u

BAT="${BAT:-/sys/class/power_supply/BAT0}"
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/battery-health"
CSV="$DIR/health.csv"
mkdir -p "$DIR"

read_val() { [ -r "$BAT/$1" ] && cat "$BAT/$1" || printf ''; }
to_wh()  { local v; v=$(read_val "$1"); [ -n "$v" ] && awk -v x="$v" 'BEGIN{printf "%.2f", x/1000000}' || printf ''; }
to_v()   { local v; v=$(read_val "$1"); [ -n "$v" ] && awk -v x="$v" 'BEGIN{printf "%.2f", x/1000000}' || printf ''; }
to_w()   { local v; v=$(read_val "$1"); [ -n "$v" ] && awk -v x="$v" 'BEGIN{printf "%.2f", x/1000000}' || printf ''; }

cap=$(read_val capacity)
status=$(read_val status)
cycles=$(read_val cycle_count)
full_raw=$(read_val energy_full)
design_raw=$(read_val energy_full_design)

health=''
if [ -n "$full_raw" ] && [ -n "$design_raw" ] && [ "$design_raw" != "0" ]; then
  health=$(awk -v f="$full_raw" -v d="$design_raw" 'BEGIN{printf "%.1f", f/d*100}')
fi

if [ ! -s "$CSV" ]; then
  printf '%s\n' "timestamp,capacity_pct,health_pct,energy_now_wh,energy_full_wh,design_wh,voltage_v,power_w,cycles,status" > "$CSV"
fi

printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
  "$(date -Iseconds)" \
  "$cap" "$health" \
  "$(to_wh energy_now)" "$(to_wh energy_full)" "$(to_wh energy_full_design)" \
  "$(to_v voltage_now)" "$(to_w power_now)" \
  "$cycles" "$status" >> "$CSV"

# Refresh the compact i3status health line (single source of truth).
if [ -x "$HOME/.local/bin/battery-health-text.sh" ]; then
  "$HOME/.local/bin/battery-health-text.sh" || true
fi
