# Battery-Powered 13.3" E-Ink Calendar

Link to amended repo:
```
https://github.com/NajidPI/InkyPiCal
```

## Raspberry Pi 2B + Pimoroni Inky Impression + Waveshare Power Management HAT (B)

> **Project status:** Development / hardware validation\
> **Target platform:** Raspberry Pi 2 Model B\
> **Display:** Pimoroni 13.3" Inky Impression Spectra 6 (PIM774)\
> **Power controller:** Waveshare Power Management HAT (B)\
> **Application:** InkyPi calendar\
> **Timezone:** Australia/Sydney

------------------------------------------------------------------------

## 1. Project Goal

The goal is to build a low-power, battery-operated wall calendar using a
large colour e-paper display.

The system should remain physically powered off for most of the day.
Once per day, the Waveshare Power Management HAT wakes the Raspberry Pi
using its RTC. The Pi boots, connects to Wi-Fi, synchronises its clock,
retrieves calendar information, renders the calendar through InkyPi,
updates the e-paper display if necessary, and shuts down cleanly.

After Linux shuts down, the Waveshare HAT should physically remove power
from the Raspberry Pi. The e-paper display requires no power to retain
the last image.

Target production flow:

``` text
RTC wake
   |
   v
Waveshare enables Pi power
   |
   v
Raspberry Pi boots
   |
   v
USB Wi-Fi connects
   |
   v
NTP / RTC time verified
   |
   v
InkyPi processes calendar
   |
   +---- image changed ----> refresh e-paper
   |
   +---- image unchanged --> leave display untouched
   |
   v
Linux clean shutdown
   |
   v
Waveshare detects Pi stopped
   |
   v
Waveshare physically cuts Pi power
   |
   v
E-paper retains image until next wake
```

A hard RTC power-off window should eventually be configured as a
fail-safe in case Linux, Wi-Fi, InkyPi, or the display hangs.

------------------------------------------------------------------------

## 2. Hardware

### Core components

  ---------------------------------------------------------------------
  Component                          Purpose
  ---------------------------------- ----------------------------------
  Raspberry Pi 2 Model B             Main computer

  Pimoroni PIM774 13.3" Inky         E-paper display
  Impression Spectra 6               

  Waveshare Power Management HAT (B) Battery charging, RTC wake, power
                                     switching and shutdown

  3.7 V 6000 mAh 1S LiPo             Main battery

  CR1220                             RTC backup battery

  Extra-long 2x20 GPIO stacking      Allows the Inky and Waveshare HAT
  header                             to share the Pi header

  USB Wi-Fi adapter                  Provides Wi-Fi because Pi 2B has
                                     no onboard wireless

  Panel-mount USB-C extension        External charging connection
  ---------------------------------------------------------------------

### Recommended Wi-Fi adapter

Prefer a Linux/Raspberry-Pi-supported adapter with an in-kernel driver.

A MediaTek **MT7612U** dual-band USB adapter is preferred over adapters
that depend on third-party Realtek driver installation.

Requirements:

-   Raspberry Pi OS support
-   USB 2.0 compatibility
-   2.4 GHz Wi-Fi support
-   Low power consumption
-   Stable reconnect after cold boot
-   No manual driver compilation if possible

5 GHz Wi-Fi is optional. For this calendar, 2.4 GHz is often preferable
because bandwidth requirements are tiny and range is generally better.

A Wi-Fi adapter is **not** a 4G/5G cellular modem. "5 GHz Wi-Fi" and "5G
mobile connectivity" are unrelated technologies.

------------------------------------------------------------------------

## 3. Why Raspberry Pi 2B?

The project originally used a Raspberry Pi 5.

Testing showed:

``` text
Waveshare + Pi 5
        -> powers on

Waveshare + Pi 5 + PIM774
        -> immediate power collapse
        -> Waveshare STA LED off
```

The failure occurred from both the LiPo and a 5 V USB supply connected
to the Waveshare HAT.

This strongly indicates that the Waveshare HAT power stage is the
bottleneck rather than battery capacity alone.

Waveshare specifies:

-   theoretical maximum output: approximately 3 A
-   practical output from a fully charged 3.7 V Li battery:
    approximately 2 A

The Pi 5 is therefore a poor match for this particular power
architecture.

### Raspberry Pi power comparison

Official Raspberry Pi approximate bare-board figures:

  ------------------------------------------------------------------------
  Raspberry   Typical active     Boot max\*    Stress max\*    Recommended
  Pi                                                                   PSU
  ----------- -------------- -------------- --------------- --------------
  Pi 2B       \~350 mA             \~0.40 A        \~0.82 A    5 V / 2.5 A

  Pi 3B       \~400 mA             \~0.75 A        \~1.34 A    5 V / 2.5 A

  Pi 3B+      \~500 mA                   \-              \-    5 V / 2.5 A

  Pi 4B       \~600 mA             \~0.85 A        \~1.25 A      5 V / 3 A

  Pi 5        \~800 mA                   \-   substantially      5 V / 5 A
                                            higher platform    recommended
                                                requirement 
  ------------------------------------------------------------------------

\* Workload measurements are approximate historical Raspberry Pi
measurements and exclude additional HAT/USB loads.

The Pi 2B therefore provides substantially more power headroom for the
large Inky display.

### Computational adequacy

The Pi 2B is easily powerful enough for this workload:

``` text
boot Raspberry Pi OS Lite
        |
connect Wi-Fi
        |
download small calendar payload
        |
Python / InkyPi rendering
        |
send 1600 x 1200 image over SPI
        |
wait for e-paper refresh
        |
shutdown
```

Rendering may be slower than on a Pi 4/5, but this has little practical
significance for a device that runs once per day.

The PIM774 itself has a nominal panel refresh of about 12 seconds, with
Pimoroni noting that a complete real-world update can take roughly 20-35
seconds depending on the Pi and panel.

------------------------------------------------------------------------

## 4. Alternative Raspberry Pi Platforms

### Pi 2B

**Advantages**

-   Lowest measured stress current among the considered full-size boards
-   Already available for this project
-   1 GB RAM is sufficient
-   Standard 40-pin GPIO
-   Good power match for Waveshare

**Disadvantages**

-   No onboard Wi-Fi
-   Requires USB Wi-Fi adapter
-   Slower boot/rendering
-   Use 32-bit Raspberry Pi OS for broadest compatibility

**Verdict:** Preferred platform if power testing succeeds.

### Pi 3B / 3B+

**Advantages**

-   Built-in Wi-Fi
-   40-pin GPIO
-   Adequate CPU/RAM
-   Lower recommended PSU rating than Pi 4/5

**Disadvantages**

-   Pi 3B historical stress measurement is actually slightly higher than
    Pi 4B
-   Less power headroom than Pi 2B

**Verdict:** Good fallback if integrated Wi-Fi is required.

### Pi 4B

**Advantages**

-   Built-in dual-band Wi-Fi
-   Much faster than necessary
-   Historical stress maximum around 1.25 A
-   Available in low-memory versions

**Disadvantages**

-   Typical active consumption is higher than Pi 2/3
-   Official recommended supply is 5 V / 3 A
-   Waveshare HAT theoretical maximum is also around 3 A

**RAM:** 1 GB is sufficient; 2 GB provides comfortable headroom. 4/8 GB
provides no meaningful benefit for this project.

**Verdict:** Viable but less desirable than Pi 2B for a
power-constrained battery appliance.

### Pi 5

**Advantages**

-   Very high performance
-   Excellent general-purpose Pi

**Disadvantages**

-   Performance is unnecessary
-   Official recommended power capability is much higher
-   Physically failed the Waveshare + PIM774 test

**Verdict:** Not suitable for the current Waveshare-powered
architecture.

------------------------------------------------------------------------

## 5. PIM774 Display

The Pimoroni 13.3" Inky Impression Spectra 6 has:

-   SKU: PIM774
-   Resolution: 1600 x 1200
-   Aspect ratio: 4:3
-   Six colours
-   Spectra 6 e-paper
-   Approximate core refresh: 12 seconds
-   Typical real-world complete refresh: approximately 20-35 seconds
-   No power required to retain an image

This last property is central to the design: the Pi can be physically
disconnected from power after every update.

Pimoroni states that Inky Impression can be used with Raspberry Pis with
a 40-pin header and specifically highlights low-power Raspberry Pi
models as a good match for e-paper applications.

### Important handling rule

**Never hot-plug the Inky GPIO header.**

Always:

``` text
shut down
disconnect USB
disconnect LiPo
connect/disconnect Inky
restore power
```

The GPIO header carries 5 V, 3.3 V, ground and GPIO signals.
Hot-plugging risks transient shorts and incorrect connection sequencing.

------------------------------------------------------------------------

## 6. GPIO Compatibility

### Waveshare Pi-side interface

The important Waveshare signals are:

  Pi GPIO   Function
  --------- -----------------------
  GPIO14    UART
  GPIO15    UART
  GPIO20    Soft shutdown request
  GPIO21    Pi running status

Internally, the Waveshare RP2040 uses:

  RP2040 GPIO   Function
  ------------- ------------------------------
  GPIO0         UART TX to Pi
  GPIO1         UART RX from Pi
  GPIO6/7       Internal I2C
  GPIO19        User key
  GPIO21        RTC interrupt
  GPIO22        Pi soft shutdown / Pi GPIO20
  GPIO23        Pi run status / Pi GPIO21
  GPIO24        Main power control
  GPIO25        STA/status LED
  GPIO29        Input voltage measurement

### Inky

The Inky uses SPI and control GPIOs. Important display signals include:

-   GPIO8 - SPI chip select
-   GPIO10 - SPI MOSI
-   GPIO11 - SPI clock
-   GPIO17 - BUSY
-   GPIO22 - D/C
-   GPIO27 - RESET

Buttons use additional GPIOs depending on board revision.

No direct conflict has been identified between the Waveshare GPIO20/21
shutdown protocol and the core PIM774 display signals.

------------------------------------------------------------------------

## 7. Physical Stack

Expected stack:

``` text
PIM774 13.3" Inky
        |
extra-long 2x20 header
        |
Waveshare Power Management HAT (B)
        |
Raspberry Pi 2B
```

Before applying power:

1.  Verify pin 1 alignment.
2.  Check that no connector is shifted by one row or column.
3.  Verify no pins are bent.
4.  Connect the display only while completely unpowered.
5.  Connect the LiPo last.

------------------------------------------------------------------------

## 8. Raspberry Pi OS Installation

Use **Raspberry Pi OS Lite 32-bit**.

A desktop environment is unnecessary and increases memory use, storage
use and boot time.

Using Raspberry Pi Imager, configure:

``` text
Hostname: inkypi
Timezone: Australia/Sydney
SSH: enabled
Username/password: user-defined
```

The Pi 2B has no onboard Wi-Fi, so network configuration requires
Ethernet initially or a recognised USB Wi-Fi adapter.

------------------------------------------------------------------------

## 9. RTL8811CU Wi-Fi Dongle Setup

The project uses the purchased **RTL8811CU USB 2.0 dual-band Wi-Fi
adapter**.

### 9.1 Detect the adapter before installing anything

Insert the dongle and boot the Pi.

Check USB detection:

``` bash
lsusb
```

Look for a Realtek/RTL8811CU or RTL8821CU-family USB wireless device.

Then check:

``` bash
ip link
```

and:

``` bash
iw dev
```

If Raspberry Pi OS already shows a wireless interface such as:

``` text
wlan0
```

**do not install another driver yet.**

Continue directly to Wi-Fi configuration.

Also inspect the loaded driver:

``` bash
sudo ethtool -i wlan0 2>/dev/null || true
```

and kernel messages:

``` bash
dmesg | grep -Ei "8811|8821|realtek|rtl|wlan"
```

### 9.2 If `wlan0` is missing

If `lsusb` detects the dongle but `ip link` / `iw dev` do not show a
wireless interface, the installed Raspberry Pi OS/kernel probably does
not have a working driver for this adapter.

Because RTL8811CU support has historically depended on out-of-tree
drivers, first ensure Ethernet is available temporarily for driver
installation.

Update the system:

``` bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

After reboot, test again:

``` bash
lsusb
ip link
iw dev
```

If `wlan0` is still absent, install build dependencies and matching
Raspberry Pi kernel headers:

``` bash
sudo apt update
sudo apt install -y raspberrypi-kernel-headers build-essential bc dkms git
```

Before compiling any external driver, verify that the installed headers
match the running kernel:

``` bash
uname -r
ls -ld /lib/modules/$(uname -r)/build
```

If the second command reports a valid directory, the build environment
is ready.

### 9.3 External RTL8811CU driver fallback

Only use an external driver if the dongle is not functional with the
stock Raspberry Pi OS installation.

Historically, Raspberry Pi-compatible RTL8811CU/RTL8821CU community
drivers have been available through projects such as:

``` text
fastoe/RTL8811CU_for_Raspbian
morrownr/8821cu-20210916
```

Driver repositories can become incompatible with newer kernels. **Do not
blindly copy an old driver command from this document months or years
later.** Check the driver's current supported kernel versions before
installing it.

Where possible, use a **DKMS-based installation**. DKMS automatically
rebuilds an out-of-tree kernel module after compatible kernel updates.

After installation/reboot, verify:

``` bash
ip link
iw dev
```

and:

``` bash
sudo ethtool -i wlan0
```

### 9.4 Important update policy

If the project requires an external RTL8811CU driver, Raspberry Pi OS
kernel upgrades become an additional reliability consideration.

Before deploying unattended:

1.  Verify Wi-Fi after every kernel update.
2.  Verify the DKMS module rebuilt successfully.
3.  Reboot and confirm `wlan0` returns automatically.
4.  Test a cold Waveshare power-on, not just a warm reboot.
5.  Confirm Wi-Fi reconnects without user interaction.

Useful checks:

``` bash
dkms status
```

``` bash
journalctl -b | grep -Ei "dkms|8811|8821|rtl|wlan"
```

For the final appliance, avoid unnecessary OS upgrades unless they have
been tested against the Wi-Fi driver.

### 9.5 Configure Wi-Fi

Set Australia as the WLAN regulatory region:

``` bash
sudo raspi-config
```

Select:

``` text
Localisation Options
 -> WLAN Country
 -> AU Australia
```

List networks:

``` bash
nmcli device wifi list
```

Connect:

``` bash
sudo nmcli device wifi connect "YOUR_WIFI_NAME" password "YOUR_WIFI_PASSWORD"
```

Verify:

``` bash
nmcli connection show
ip addr show wlan0
```

Test IP connectivity:

``` bash
ping -c 4 1.1.1.1
```

Test DNS:

``` bash
ping -c 4 google.com
```

### 9.6 Test automatic reconnection

Because this Pi will cold-boot unattended once per day, automatic Wi-Fi
reconnection is essential.

Check the connection profile:

``` bash
nmcli connection show
```

Then shut the Pi down:

``` bash
sudo shutdown -h now
```

Allow the Waveshare to remove power, then perform another cold start.

After boot:

``` bash
nmcli device status
```

Expected:

``` text
wlan0    wifi    connected
```

Also test:

``` bash
ping -c 4 1.1.1.1
ping -c 4 google.com
```

Do this several times before production deployment.

### 9.7 Wi-Fi power impact

The RTL8811CU adapter is specified at **\<1 W**.

At 5 V:

``` text
<1 W / 5 V
     =
<0.2 A
```

The USB adapter therefore consumes some of the Waveshare's limited
output-current budget, but it remains substantially more practical with
the low-power Pi 2B than the original Pi 5 configuration.

The final validation remains physical:

``` text
Waveshare
   |
Pi 2B
   +-- RTL8811CU Wi-Fi
   +-- PIM774
```

must survive boot, Wi-Fi activity and repeated full PIM774 refreshes
without undervoltage or HAT shutdown.

------------------------------------------------------------------------

## 10. Base OS Configuration

Update the system:

``` bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

Verify timezone and NTP:

``` bash
timedatectl
```

If required:

``` bash
sudo timedatectl set-timezone Australia/Sydney
sudo timedatectl set-ntp true
```

Verify:

``` bash
cat /etc/os-release
uname -a
```

------------------------------------------------------------------------

## 11. Power Validation

Before installing InkyPi:

``` bash
vcgencmd get_throttled
```

Ideal:

``` text
throttled=0x0
```

Search for voltage problems:

``` bash
dmesg | grep -Ei "voltage|under.?voltage|thrott"
```

and:

``` bash
journalctl -b | grep -Ei "voltage|under.?voltage|thrott"
```

Raspberry Pi boards have low-voltage detection. A non-zero
`get_throttled` value must be investigated before considering the
appliance reliable.

### Required hardware test

Cold assemble:

``` text
6000 mAh LiPo
      |
Waveshare HAT
      |
Raspberry Pi 2B
      |
PIM774
```

Boot and check:

-   Waveshare STA remains active
-   Pi PWR LED remains active
-   Pi ACT LED shows boot activity
-   Linux boots
-   Wi-Fi connects
-   `vcgencmd get_throttled` remains clean

Then perform multiple full PIM774 refreshes and check `get_throttled`
after each one.

A recommended validation sequence is at least 3-5 refresh cycles
followed by a cold reboot and another refresh.

------------------------------------------------------------------------

## 12. Installing InkyPi

Repository:

https://github.com/fatihak/InkyPi

Install:

``` bash
cd ~
sudo apt install -y git
git clone https://github.com/fatihak/InkyPi.git
cd InkyPi
sudo bash install/install.sh
```

Do **not** use InkyPi's `-W` installer option for this display; that
option is intended for Waveshare displays rather than the Pimoroni Inky.

Reboot when installation is complete:

``` bash
sudo reboot
```

Open:

``` text
http://inkypi.local
```

or:

``` text
http://PI_IP_ADDRESS
```

Configure:

-   Pimoroni 13.3" Inky / PIM774
-   Australia/Sydney
-   Calendar plugin
-   desired playlist/layout

------------------------------------------------------------------------

## 13. InkyPi Refresh Behaviour

InkyPi performs background refresh checks rather than guaranteeing an
immediate display refresh merely because Linux has booted.

For the battery appliance, reduce the global plugin cycle interval.

Edit:

``` bash
nano ~/InkyPi/src/config/device.json
```

Change:

``` json
"plugin_cycle_interval_seconds": 3600
```

to approximately:

``` json
"plugin_cycle_interval_seconds": 30
```

Restart:

``` bash
sudo systemctl restart inkypi.service
```

### Image hashing

InkyPi hashes generated images.

If the newly rendered calendar is identical to the currently displayed
image, it can skip the physical e-paper refresh.

This is desirable:

``` text
calendar processed
      |
      v
new image hash
      |
      +-- changed --> update PIM774
      |
      +-- same ----> skip physical refresh
```

An unchanged display therefore does **not** automatically indicate a
failed update.

The production shutdown coordinator should consider a completed InkyPi
processing cycle successful even if the display itself does not
physically refresh.

------------------------------------------------------------------------

## 14. Waveshare Power Management HAT (B)

Important hardware:

-   RP2040 MCU
-   RTC
-   MP28167-A buck-boost converter
-   INA219 current/power monitoring
-   battery charging/protection circuitry
-   USB 5 V input
-   3.3-4.2 V PH2.0 battery input
-   status LED
-   GPIO-based Raspberry Pi shutdown handshake

The current Waveshare wiki identifies the RTC as PCF8523 in its feature
section, although some Waveshare documentation/resources have referenced
PCF85063-family hardware. Verify the actual board revision if
RTC-specific firmware work depends on this detail.

### Power capability

Waveshare states:

``` text
Theoretical maximum output: ~3 A
Practical maximum with fully charged 3.7 V LiPo: ~2 A
```

This limitation is why Raspberry Pi selection matters significantly.

Battery capacity and instantaneous current capability are different:

``` text
6000 mAh battery
      !=
6 A available to the Pi
```

Increasing battery capacity alone does not bypass the Waveshare
converter's output-current limitation.

------------------------------------------------------------------------

## 15. Waveshare Soft-Shutdown Integration

Install the Pi-side shutdown software:

``` bash
cd ~
wget https://files.waveshare.com/upload/4/44/Power-Management-HAT.zip
unzip Power-Management-HAT.zip
cd Power-Management-HAT
sudo chmod a+x Power-Management-HAT-Setup.sh
sudo ./Power-Management-HAT-Setup.sh
```

Reboot when prompted.

The intended handshake is:

``` text
RP2040
   |
GPIO20 shutdown request
   |
   v
Raspberry Pi
   |
Linux shutdown
   |
GPIO21 run state drops
   |
   v
RP2040
   |
cut Pi power
```

This is important because `shutdown -h now` by itself halts Linux but
does not necessarily guarantee that the external HAT removes power
unless the shutdown handshake is functioning.

------------------------------------------------------------------------

## 16. Daily Shutdown Coordinator

Target path:

``` text
/usr/local/bin/inky-daily-update.sh
```

Recommended implementation:

``` bash
#!/bin/bash

set -uo pipefail

LOG_TAG="inky-daily"

NETWORK_TIMEOUT=180
TIME_TIMEOUT=90
REFRESH_TIMEOUT=300
DISPLAY_SETTLE_SECONDS=30

INKYPI_DIR="/home/pi/InkyPi"

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
    if [ -d "$INKYPI_DIR" ]; then
        return
    fi

    for path in /home/*/InkyPi /usr/local/inkypi
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

    print(data.get("refresh_info", {}).get("refresh_time", ""))
except Exception:
    print("")
PY
}

log "========================================="
log "Starting daily InkyPi update"
log "========================================="

find_inkypi
CONFIG_FILE="$INKYPI_DIR/src/config/device.json"

log "InkyPi directory: $INKYPI_DIR"
log "Config file: $CONFIG_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
    log "ERROR: InkyPi device.json not found."
    shutdown_pi
    exit 1
fi

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
log "Waiting for system time synchronization..."

elapsed=0

while true
do
    synced="$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo no)"

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

OLD_REFRESH="$(get_refresh_time)"
log "Current refresh timestamp: ${OLD_REFRESH:-none}"
log "Waiting for InkyPi refresh cycle..."

elapsed=0
UPDATED=0

while [ "$elapsed" -lt "$REFRESH_TIMEOUT" ]
do
    NEW_REFRESH="$(get_refresh_time)"

    if [ -n "$NEW_REFRESH" ] && [ "$NEW_REFRESH" != "$OLD_REFRESH" ]; then
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

if [ "$UPDATED" -eq 1 ]; then
    log "Refresh cycle successfully processed."
    log "Waiting ${DISPLAY_SETTLE_SECONDS}s for display controller..."
    sleep "$DISPLAY_SETTLE_SECONDS"
else
    log "No InkyPi refresh detected within ${REFRESH_TIMEOUT}s."
    log "Existing e-ink image will remain displayed."
fi

log "Daily update process complete."
shutdown_pi
```

**Important:** set `INKYPI_DIR` to the real user path. Locate it with:

``` bash
find /home -maxdepth 2 -type d -name InkyPi 2>/dev/null
```

Make executable:

``` bash
sudo chmod +x /usr/local/bin/inky-daily-update.sh
```

Manual debug:

``` bash
sudo bash -x /usr/local/bin/inky-daily-update.sh
```

Do not rely on `$SUDO_USER` in this script when `set -u` is enabled.
Direct execution without `sudo` may leave `SUDO_USER` unset and
terminate the script before shutdown.

------------------------------------------------------------------------

## 17. Systemd Production Service

Create:

``` text
/etc/systemd/system/inkypi-daily-update.service
```

Contents:

``` ini
[Unit]
Description=Daily InkyPi Calendar Update
After=network-online.target inkypi.service
Wants=network-online.target
Requires=inkypi.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/inky-daily-update.sh
TimeoutStartSec=10min
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

Reload:

``` bash
sudo systemctl daemon-reload
```

### Development mode

Keep automatic shutdown disabled:

``` bash
sudo systemctl disable inkypi-daily-update.service
```

This allows SSH and InkyPi web development without the machine shutting
itself down.

### Production mode

Enable:

``` bash
sudo systemctl enable inkypi-daily-update.service
```

Check:

``` bash
systemctl is-enabled inkypi-daily-update.service
```

------------------------------------------------------------------------

## 18. Waveshare RTC / RP2040 Scheduling

Download the Waveshare example firmware:

``` bash
cd ~
sudo apt install p7zip-full -y
wget https://files.waveshare.com/upload/2/27/Power-example.7z
7z x Power-example.7z
```

Find schedule definitions rather than assuming a particular source
filename:

``` bash
cd ~/Power-example
grep -Rni "Power_On_Time" .
grep -Rni "Power_Off_Time" .
```

The `Period_Time` demo provides scheduled power-on/off behaviour.

Find where it is selected:

``` bash
grep -n "Period_Time" ~/Power-example/main.c
```

A target production schedule is approximately:

``` text
23:57 - RTC powers Pi on
00:10 - hard fail-safe cutoff
```

### Midnight warning

Verify that the Waveshare `Period_Time` implementation correctly handles
an ON/OFF window crossing midnight.

If it does not, use a same-day window such as:

``` text
23:55:00 ON
23:59:30 OFF
```

and render the next day's calendar, or modify the RP2040 firmware logic
explicitly.

Always test with an RTC wake only a few minutes in the future before
deploying a once-per-day schedule.

------------------------------------------------------------------------

## 19. RP2040 Firmware Compilation

Example:

``` bash
cd ~/Power-example/build
export PICO_SDK_PATH=/home/$USER/pico/pico-sdk
cmake ..
make -j
```

Expected firmware:

``` text
Power_Management_HAT.elf
```

Waveshare also supports RP2040 programming via USB/UF2 or SWD.

**Important:** programming/resetting the RP2040 can interrupt HAT output
power. Do not flash the RP2040 while relying on that same output to keep
the Pi alive.

------------------------------------------------------------------------

## 20. Failure Strategy

The e-paper's persistent image enables a safe failure policy.

### Network failure

``` text
Wi-Fi unavailable
     |
wait up to timeout
     |
keep existing display
     |
shutdown
```

### Calendar/API failure

Do not blank the display. Preserve the existing e-paper image and shut
down.

### No visual change

If InkyPi generates the same image, skipping the physical display update
is a successful result.

### Linux hangs

The RP2040 RTC schedule should provide a hard power-off fail-safe.

### Battery becomes low

The Waveshare can monitor voltage/current and can be programmed to cut
output before excessive battery discharge.

------------------------------------------------------------------------

## 21. Development vs Production Modes

### Development

``` text
RTC auto wake: optional
daily auto shutdown: OFF
SSH: available
InkyPi web UI: available
manual refreshes: allowed
```

### Production

``` text
RTC wake: ON
daily update service: ON
SSH: normally unnecessary
InkyPi refresh/check: automatic
Linux shutdown: automatic
physical power cut: automatic
RTC fail-safe cutoff: ON
```

------------------------------------------------------------------------

## 22. Acceptance Tests

Do not consider the build production-ready until all of the following
pass.

### Power

-   [ ] Pi 2B cold boots from Waveshare + LiPo with PIM774 connected.
-   [ ] Waveshare STA remains operational.
-   [ ] Wi-Fi dongle connects reliably.
-   [ ] `vcgencmd get_throttled` returns `0x0`.
-   [ ] No kernel undervoltage warnings.
-   [ ] At least five PIM774 refreshes complete.
-   [ ] `get_throttled` remains clean after refreshes.
-   [ ] Cold reboot + Wi-Fi + refresh succeeds.

### InkyPi

-   [ ] Web UI available.
-   [ ] Calendar plugin works.
-   [ ] Correct timezone.
-   [ ] Correct PIM774 display.
-   [ ] Same-image refresh is skipped correctly.
-   [ ] Calendar changes cause a physical display refresh.

### Waveshare

-   [ ] Soft shutdown request reaches Pi.
-   [ ] Pi performs clean Linux shutdown.
-   [ ] Waveshare detects stopped Pi.
-   [ ] Waveshare physically removes Pi power.
-   [ ] RTC can wake the Pi.
-   [ ] Hard fail-safe cutoff works.
-   [ ] LiPo charging works through panel USB-C.

### Production workflow

-   [ ] Cold RTC wake.
-   [ ] Wi-Fi connection.
-   [ ] Time synchronisation.
-   [ ] Calendar processing.
-   [ ] Display update when necessary.
-   [ ] Existing image retained on failure/no-change.
-   [ ] Clean shutdown.
-   [ ] Physical power removal.
-   [ ] Successful next-day wake.

------------------------------------------------------------------------

## 23. Troubleshooting

### Waveshare STA goes completely dark when display is attached

This was observed with the Raspberry Pi 5.

Likely causes include:

1.  upstream power collapse
2.  HAT converter over-current/protection
3.  5 V rail collapse
4.  3.3 V rail collapse
5.  physical header short/misalignment

A GPIO software conflict alone would not normally explain the HAT
MCU/status LED losing power.

### Pi boots but reports undervoltage

Run:

``` bash
vcgencmd get_throttled
```

and:

``` bash
journalctl -b | grep -Ei "voltage|under.?voltage|thrott"
```

Do not deploy unattended until resolved.

### Wi-Fi adapter appears in `lsusb` but not `wlan0`

Check:

``` bash
dmesg | tail -100
iw dev
rfkill
```

Prefer an adapter with an in-kernel Linux driver instead of maintaining
a third-party driver.

### Calendar unchanged after update

This may be normal. InkyPi hashes images and can skip a physical refresh
when the new image is identical.

Check:

``` bash
sudo journalctl -u inkypi.service -n 100 --no-pager
```

Look for messages indicating either display update or same-image skip.

------------------------------------------------------------------------

## 24. Useful Commands

``` bash
# Power/undervoltage state
vcgencmd get_throttled

# Wi-Fi
ip link
iw dev
nmcli device wifi list
nmcli connection show

# USB adapter
lsusb

# Time
timedatectl

# InkyPi
systemctl status inkypi.service
sudo journalctl -u inkypi.service -n 100 --no-pager

# Daily coordinator
systemctl status inkypi-daily-update.service
sudo journalctl -u inkypi-daily-update.service -b --no-pager

# Find InkyPi
find /home -maxdepth 2 -type d -name InkyPi 2>/dev/null

# Look for undervoltage
journalctl -b | grep -Ei "voltage|under.?voltage|thrott"
```

------------------------------------------------------------------------

## 25. References

-   Raspberry Pi documentation - power requirements and approximate
    current measurements:\
    https://www.raspberrypi.com/documentation/computers/raspberry-pi.html

-   Raspberry Pi getting started / recommended power supplies:\
    https://www.raspberrypi.com/documentation/computers/getting-started.html

-   Waveshare Power Management HAT (B) wiki:\
    https://www.waveshare.com/wiki/Power_Management_HAT\_%28B%29

-   Pimoroni PIM774 / Inky Impression specifications:\
    https://shop.pimoroni.com/products/inky-impression

-   Pimoroni Inky Impression getting-started guide:\
    https://learn.pimoroni.com/article/getting-started-with-inky-impression

-   Pimoroni Inky library:\
    https://github.com/pimoroni/inky

-   InkyPi:\
    https://github.com/fatihak/InkyPi

------------------------------------------------------------------------

## 26. Current Recommended Architecture

``` text
                    External USB-C
                          |
                          v
               +---------------------+
               | Waveshare Power HAT |
               |                     |
6000mAh LiPo ->| charger             |
               | buck/boost          |
CR1220 ------->| RTC                 |
               | RP2040              |
               +----------+----------+
                          |
                     switched power
                          |
                          v
                +-------------------+
                | Raspberry Pi 2B   |
                |                   |
                | USB -> Wi-Fi      |
                | GPIO -> PIM774    |
                +---------+---------+
                          |
                          v
                +-------------------+
                | 13.3" Spectra 6   |
                | E-Paper Calendar  |
                +-------------------+

When update completes:

Pi shutdown
    |
GPIO21 state changes
    |
RP2040 detects shutdown
    |
Waveshare cuts switched power
    |
Pi + Wi-Fi + display electronics consume no operating power
    |
E-paper image remains visible
```

------------------------------------------------------------------------

## 27. Design Decision Summary

The major design lesson from initial prototyping was that **CPU
performance is not the limiting factor; peak power delivery is**.

The Pi 5 provided substantially more compute capability than the
application needed and exceeded what the Waveshare power path could
reliably provide once the PIM774 was attached.

The Pi 2B changes the design priorities:

-   much lower Pi current
-   enough CPU performance
-   inexpensive external Wi-Fi
-   standard GPIO compatibility
-   substantially greater power headroom
-   potentially longer battery runtime

The remaining unknown is the complete system's transient load during a
PIM774 refresh. Therefore, the Pi 2B architecture should be considered
**provisionally selected pending repeated physical power/undervoltage
testing**.

Once those tests pass, the intended production design is:

> **RTC wake -\> Pi 2B boot -\> Wi-Fi -\> InkyPi calendar -\>
> conditional e-paper refresh -\> clean shutdown -\> Waveshare power
> cut.**
