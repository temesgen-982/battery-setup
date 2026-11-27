#!/usr/bin/env bash
# Install the daily health refresh as a *user* timer (no sudo needed).
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
USER_UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
BIN_DIR="$HOME/.local/bin"

install -d "$USER_UNIT_DIR" "$BIN_DIR"
install -m755 "$SRC/battery-health-text.sh" "$BIN_DIR/battery-health-text.sh"
install -m644 "$SRC/systemd/user/battery-health-refresh.service" "$USER_UNIT_DIR/"
install -m644 "$SRC/systemd/user/battery-health-refresh.timer" "$USER_UNIT_DIR/"

systemctl --user daemon-reload
systemctl --user enable --now battery-health-refresh.timer
"$BIN_DIR/battery-health-text.sh" || true

echo
systemctl --user list-timers battery-health-refresh.timer --no-pager || true
