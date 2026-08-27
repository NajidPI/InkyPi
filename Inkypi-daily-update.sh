#!/bin/bash

set -u

LOG_TAG="inkypi-daily"
INKYPI_DIR="/home/$SUDO_USER/InkyPi"

# Fallback when executed by systemd/root
if [ ! -d "$INKYPI_DIR" ]; then
    INKYPI_DIR="$(find /home -maxdepth 2 -type d -name InkyPi | head -n 1)"
fi

CONFIG_FILE="$INKYPI_DIR/src/config/device.json"

log() {
    logger -t "$LOG_TAG" "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

get_refresh_time() {
    python3 - "$CONFIG_FILE" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r") as f:
        data = json.load(f)

    print(data.get("refresh_info", {}).get("refresh_time", ""))
except Exception:
    print("")
PY
}

log "Daily calendar update started"

#
# 1. Wait for network
#
NETWORK_TIMEOUT=180
elapsed=0

while ! ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; do
    if [ "$elapsed" -ge "$NETWORK_TIMEOUT" ]; then
        log "Network unavailable after ${NETWORK_TIMEOUT}s"
        log "Leaving existing e-ink image intact"
        sync
        shutdown -h now
        exit 1
    fi

    sleep 5
    elapsed=$((elapsed + 5))
done

log "Network available"

#
# 2. Wait for NTP/system clock
#
TIME_TIMEOUT=90
elapsed=0

while true; do
    synced="$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo no)"

    if [ "$synced" = "yes" ]; then
        break
    fi

    if [ "$elapsed" -ge "$TIME_TIMEOUT" ]; then
        log "NTP did not confirm synchronization; continuing using RTC/system time"
        break
    fi

    sleep 5
    elapsed=$((elapsed + 5))
done

log "Time ready: $(date --iso-8601=seconds)"

#
# 3. Ensure InkyPi is running
#
systemctl start inkypi.service

INKY_TIMEOUT=90
elapsed=0

while ! systemctl is-active --quiet inkypi.service; do
    if [ "$elapsed" -ge "$INKY_TIMEOUT" ]; then
        log "InkyPi service failed to start"
        sync
        shutdown -h now
        exit 1
    fi

    sleep 2
    elapsed=$((elapsed + 2))
done

log "InkyPi service running"

#
# 4. Record previous refresh timestamp
#
if [ ! -f "$CONFIG_FILE" ]; then
    log "Could not find InkyPi config file: $CONFIG_FILE"
    sync
    shutdown -h now
    exit 1
fi

OLD_REFRESH="$(get_refresh_time)"

log "Previous refresh: ${OLD_REFRESH:-none}"

#
# 5. Wait for InkyPi playlist refresh
#
# InkyPi should have plugin_cycle_interval_seconds configured
# to ~30 seconds.
#
REFRESH_TIMEOUT=300
elapsed=0
UPDATED=0

while [ "$elapsed" -lt "$REFRESH_TIMEOUT" ]; do

    NEW_REFRESH="$(get_refresh_time)"

    if [ -n "$NEW_REFRESH" ] && [ "$NEW_REFRESH" != "$OLD_REFRESH" ]; then
        UPDATED=1
        log "Refresh completed: $NEW_REFRESH"
        break
    fi

    if ! systemctl is-active --quiet inkypi.service; then
        log "InkyPi stopped unexpectedly"
        break
    fi

    sleep 5
    elapsed=$((elapsed + 5))
done

if [ "$UPDATED" -eq 0 ]; then
    log "No completed refresh detected within ${REFRESH_TIMEOUT}s"
    log "Existing display will remain unchanged"
else
    #
    # 6. Give e-ink hardware generous settling time
    #
    log "Allowing display controller to settle"
    sleep 30
fi

#
# 7. Flush filesystem
#
sync

log "Daily update complete; shutting down"

#
# 8. Graceful shutdown.
# Waveshare HAT should detect the Pi run signal dropping
# and remove main power.
#
shutdown -h now
