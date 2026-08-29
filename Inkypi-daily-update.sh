#!/bin/bash

set -uo pipefail

LOG_TAG="inky-daily"

# ============================================================
# CONFIGURATION
# ============================================================

NETWORK_TIMEOUT=180
TIME_TIMEOUT=90
REFRESH_TIMEOUT=300
DISPLAY_SETTLE_SECONDS=30

# Change this if your InkyPi directory is somewhere else.
INKYPI_DIR="/home/$SUDO_USER/InkyPi"


# ============================================================
# FUNCTIONS
# ============================================================

log() {
    local message="$1"

    logger -t "$LOG_TAG" "$message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message"
}


shutdown_pi() {

    log "Syncing filesystem..."

    sync

    log "Shutting Raspberry Pi down..."

    /usr/sbin/shutdown -h now
}


find_inkypi() {

    # Use configured path first.
    if [ -d "$INKYPI_DIR" ]; then
        return
    fi

    # Try common locations.
    for path in \
        /home/*/InkyPi \
        /usr/local/inkypi
    do
        if [ -d "$path" ]; then
            INKYPI_DIR="$path"
            return
        fi
    done

    log "ERROR: Could not locate InkyPi installation."
    exit 1
}


get_refresh_time() {

    python3 - "$CONFIG_FILE" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r") as f:
        data = json.load(f)

    print(
        data.get(
            "refresh_info",
            {}
        ).get(
            "refresh_time",
            ""
        )
    )

except Exception:
    print("")
PY
}


# ============================================================
# START
# ============================================================

log "========================================="
log "Starting daily InkyPi update"
log "========================================="


# ============================================================
# LOCATE INKYPI
# ============================================================

find_inkypi

CONFIG_FILE="$INKYPI_DIR/src/config/device.json"

log "InkyPi directory: $INKYPI_DIR"
log "Config file: $CONFIG_FILE"


if [ ! -f "$CONFIG_FILE" ]; then

    log "ERROR: InkyPi device.json not found."

    shutdown_pi
    exit 1
fi


# ============================================================
# WAIT FOR NETWORK
# ============================================================

log "Waiting for network..."

elapsed=0

while ! ping -c1 -W2 1.1.1.1 >/dev/null 2>&1
do

    if [ "$elapsed" -ge "$NETWORK_TIMEOUT" ]; then

        log "Network unavailable after ${NETWORK_TIMEOUT}s."
        log "Keeping existing e-ink image."

        shutdown_pi
        exit 1
    fi

    sleep 5

    elapsed=$((elapsed + 5))

done


log "Network available."


# ============================================================
# WAIT FOR CLOCK SYNC
# ============================================================

log "Waiting for system time synchronization..."

elapsed=0

while true
do

    synced="$(timedatectl show \
        -p NTPSynchronized \
        --value 2>/dev/null || echo no)"

    if [ "$synced" = "yes" ]; then

        log "System clock synchronized."
        break

    fi


    if [ "$elapsed" -ge "$TIME_TIMEOUT" ]; then

        log "NTP timeout."
        log "Continuing using current system/RTC time."

        break

    fi


    sleep 5

    elapsed=$((elapsed + 5))

done


log "Current time: $(date --iso-8601=seconds)"


# ============================================================
# START INKYPI
# ============================================================

log "Starting InkyPi service..."

systemctl start inkypi.service


elapsed=0

while ! systemctl is-active --quiet inkypi.service
do

    if [ "$elapsed" -ge 60 ]; then

        log "ERROR: InkyPi service failed to start."

        shutdown_pi
        exit 1

    fi


    sleep 2

    elapsed=$((elapsed + 2))

done


log "InkyPi service is running."


# ============================================================
# RECORD CURRENT REFRESH
# ============================================================

OLD_REFRESH="$(get_refresh_time)"

log "Current refresh timestamp: ${OLD_REFRESH:-none}"


# ============================================================
# WAIT FOR INKYPI CYCLE
# ============================================================

log "Waiting for InkyPi refresh cycle..."

elapsed=0
UPDATED=0


while [ "$elapsed" -lt "$REFRESH_TIMEOUT" ]
do

    NEW_REFRESH="$(get_refresh_time)"


    if [ -n "$NEW_REFRESH" ] &&
       [ "$NEW_REFRESH" != "$OLD_REFRESH" ]; then

        UPDATED=1

        log "InkyPi cycle completed."
        log "New refresh timestamp: $NEW_REFRESH"

        break

    fi


    if ! systemctl is-active --quiet inkypi.service; then

        log "ERROR: InkyPi stopped unexpectedly."

        break

    fi


    sleep 5

    elapsed=$((elapsed + 5))

done


# ============================================================
# HANDLE RESULT
# ============================================================

if [ "$UPDATED" -eq 1 ]; then

    log "Refresh cycle successfully processed."

    log "Waiting ${DISPLAY_SETTLE_SECONDS}s for display controller..."

    sleep "$DISPLAY_SETTLE_SECONDS"

else

    log "No InkyPi refresh detected within ${REFRESH_TIMEOUT}s."

    log "Existing e-ink image will remain displayed."

fi


# ============================================================
# SHUTDOWN
# ============================================================

log "Daily update process complete."

shutdown_pi
