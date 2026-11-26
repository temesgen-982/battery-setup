# battery-setup

Battery longevity + health monitoring for a **Lenovo ThinkPad T590** running Debian.

Two small, independent pieces:

1. **Charge threshold** — stops charging at 80% (resumes below 75%) instead of holding
   the pack at 100%, which is the single biggest lever for slowing Li-ion wear.
2. **Weekly health logger** — appends one CSV row per week so you can judge the real
   degradation *trend* instead of panicking over a single reading.

Everything here is plain shell + systemd units. No daemons, no packages.

---

## Contents

| File | Role |
|---|---|
| `battery-charge-threshold.service` | Oneshot: writes the 75/80 thresholds at boot |
| `battery-health.service` | Oneshot: runs the logger as the invoking user |
| `battery-health.timer` | Weekly schedule (`Mon 09:00`), `Persistent=true` |
| `battery-health-log.sh` | Appends one row to the CSV |
| `battery-trend` | Pretty-prints the CSV with deltas, sparkline, rate/month |
| `install.sh` | Installs scripts + units, enables them, removes legacy cron |
| `README.md` | This file |

## Requirements

- A ThinkPad whose EC exposes the charge knobs, i.e. this exists:
  `/sys/class/power_supply/BAT0/charge_control_end_threshold`
- `systemd`
- `sudo` (installation only)
- Tested on: ThinkPad **T590** (type 20N5), Debian 13, battery `5B10W13913` (57 Wh)

## Install

```bash
sudo bash install.sh
```

The installer:

1. copies `battery-health-log.sh` and `battery-trend` to `~/.local/bin/`
2. installs the three units to `/etc/systemd/system/`
3. rewrites the logger unit to run as the invoking user
4. enables + starts the threshold service and the weekly timer
5. removes any old per-user cron entry for the logger (avoids duplicate rows)

## Verify

```bash
# thresholds currently applied
cat /sys/class/power_supply/BAT0/charge_control_start_threshold   # 75
cat /sys/class/power_supply/BAT0/charge_control_end_threshold     # 80

# service + timer
systemctl status battery-charge-threshold.service
systemctl list-timers battery-health.timer

# take a snapshot on demand
battery-health-log.sh
battery-trend
```

## Usage

```bash
battery-trend
```

Output looks like:

```
Battery health trend
  log: ~/.local/share/battery-health/health.csv

  timestamp             cap%  health%    delta  trend
  2026-11-26T23:16:01     97     58.2      —  ▄
  ...
Summary
  latest         : 58.2%  (2026-11-26)
  first -> latest: 58.2% -> 58.2%  (delta +0.0 pts, 3 row(s))
  span           : 14.0 days
  rate           : +0.00 pts/month
```

`battery-trend` accepts an alternate CSV path as its first argument.

## Configuration

### Change the cap permanently

Edit the `ExecStart` line in `/etc/systemd/system/battery-charge-threshold.service`,
then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart battery-charge-threshold.service
```

### Temporarily allow a full charge (e.g. before travel)

```bash
sudo sh -c 'echo 100 > /sys/class/power_supply/BAT0/charge_control_end_threshold'
```

The boot service re-applies 80% on the next reboot.

### Change the schedule

Edit `OnCalendar=` in `/etc/systemd/system/battery-health.timer`, then
`sudo systemctl daemon-reload && sudo systemctl restart battery-health.timer`.

## How it works

**Threshold.** The kernel exposes the EC's charge window through sysfs. Writing
`charge_control_end_threshold` makes the embedded controller stop charging at that
level; `charge_control_start_threshold` is the level at which it resumes. The values
are volatile, so `battery-charge-threshold.service` re-applies them on every boot.

**Logger.** `battery-health-log.sh` reads `/sys/class/power_supply/BAT0/*` and appends
a CSV row. Health is computed as `energy_full / energy_full_design * 100`. The timer
uses `Persistent=true`, so a week missed while the laptop was off is back-filled on
the next boot.

**Data location.** `~/.local/share/battery-health/health.csv` — deliberately kept
*outside* this folder so the repo stays free of personal machine data.

CSV columns:

```
timestamp, capacity_pct, health_pct, energy_now_wh, energy_full_wh,
design_wh, voltage_v, power_w, cycles, status
```

## Caveats

- **A threshold does not force discharge.** If the battery is above the cap when you
  install, it simply stops charging and stays there until you unplug and use it.
  To enter the 75–80% band, run it down below 80% once, then plug back in.
- `energy_full` is a *learned estimate* from the battery's fuel gauge, not a hard
  measurement. Expect ±2–4 points of jitter, and occasional step changes after a
  full cycle, a long rest, or an EC/BIOS update. Judge the trend, not one reading.
- `energy_full_design` can be misreported by some firmware; health % is only as
  trustworthy as that value.
- This slows wear; it does not reverse it. A worn pack stays worn.

## Uninstall

```bash
sudo systemctl disable --now battery-charge-threshold.service battery-health.timer
sudo rm /etc/systemd/system/battery-{charge-threshold.service,health.service,health.timer}
sudo systemctl daemon-reload
rm -f ~/.local/bin/battery-health-log.sh ~/.local/bin/battery-trend
```

The threshold then reverts to 100% on the next boot. Your CSV history is untouched.

## Version control

Tracking this folder with git is normal and safe — it is exactly the kind of small,
personal tooling people keep in a **dotfiles repo**. A few conventions:

- `health.csv` and any `*.csv`/`*.log` are git-ignored; the data is machine-specific.
- The unit files contain your username and home path (rewritten by `install.sh`),
  so treat them as personal config, not a generic package.
- If you publish it, templatize the user/path instead of committing real ones.

Typical dotfiles setups either symlink this folder into `~/.local/share`, or keep it
as its own repo and run `install.sh` on each machine.
