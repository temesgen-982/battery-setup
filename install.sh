#!/usr/bin/env bash
# Install the battery charge threshold + weekly health logger.
# Run as root:  sudo bash install.sh
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="${SUDO_USER:-temesgen}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo: sudo bash $0" >&2
  exit 1
fi

# 1) install the user-facing scripts
install -d -o "$USER_NAME" -g "$USER_NAME" "$HOME_DIR/.local/bin"
install -m755 -o "$USER_NAME" -g "$USER_NAME" \
  "$SRC/battery-health-log.sh" "$HOME_DIR/.local/bin/battery-health-log.sh"
install -m755 -o "$USER_NAME" -g "$USER_NAME" \
  "$SRC/battery-trend" "$HOME_DIR/.local/bin/battery-trend"

# 2) install the systemd units
install -m644 "$SRC/battery-charge-threshold.service" /etc/systemd/system/
install -m644 "$SRC/battery-health.service" /etc/systemd/system/
install -m644 "$SRC/battery-health.timer" /etc/systemd/system/

# make the logger run as the real user
sed -i "s/^User=.*/User=$USER_NAME/; s/^Group=.*/Group=$USER_NAME/" /etc/systemd/system/battery-health.service
sed -i "s#^ExecStart=.*#ExecStart=$HOME_DIR/.local/bin/battery-health-log.sh#" /etc/systemd/system/battery-health.service

systemctl daemon-reload
systemctl enable --now battery-charge-threshold.service
systemctl enable --now battery-health.timer

# 3) drop the old per-user cron entry so rows aren't duplicated
if crontab -u "$USER_NAME" -l >/dev/null 2>&1; then
  crontab -u "$USER_NAME" -l | grep -v 'battery-health-log.sh' | crontab -u "$USER_NAME" - || true
fi

echo
echo "== applied threshold =="
echo "start = $(cat /sys/class/power_supply/BAT0/charge_control_start_threshold)"
echo "end   = $(cat /sys/class/power_supply/BAT0/charge_control_end_threshold)"
echo
echo "== timer =="
systemctl list-timers battery-health.timer --no-pager || true
echo
echo "Done. Log a snapshot now with:  $HOME_DIR/.local/bin/battery-health-log.sh"
