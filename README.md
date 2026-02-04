# Brother QL-1100 Print Server for Raspberry Pi

Complete setup guide to configure your Raspberry Pi as a CUPS print server for the Brother QL-1100 label printer with network printing support.

**Tested on:** Raspberry Pi OS Bookworm (ARMv7l/ARMhf)

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [System Preparation](#system-preparation)
3. [Install CUPS & Dependencies](#install-cups--dependencies)
4. [Disable Conflicting Services](#disable-conflicting-services)
5. [Download & Install Brother Driver](#download--install-brother-driver)
6. [Configure the Printer in CUPS](#configure-the-printer-in-cups)
7. [Lock Default Settings](#lock-default-settings)
8. [Configure Network Access](#configure-network-access)
9. [Testing & Verification](#testing--verification)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware
- Raspberry Pi (any model with USB and network connectivity)
- Brother QL-1100 label printer
- Brother DK-1247 labels (103mm x 164mm / 4.07" x 6.46")
- USB cable
- Network connection (WiFi or Ethernet)

### Knowledge Level
- Basic Linux command line experience
- SSH access to Raspberry Pi (or keyboard/monitor)

---

## System Preparation

### 1. Update System
Refresh the package lists and upgrade all installed packages:

```bash
sudo apt update
sudo apt upgrade -y
```

**Note:** If you see a message about system restart being required, reboot:
```bash
sudo reboot
```

---

## Install CUPS & Dependencies

### 1. Install CUPS and Required Packages
```bash
sudo apt install -y cups cups-bsd cups-client ghostscript avahi-daemon cups-filters psutils avahi-utils
```

**What each package does:**
- `cups` - The print server software
- `cups-bsd` - BSD LPD/LPR compatibility commands
- `cups-client` - Command-line printing tools
- `ghostscript` - Required for rendering PostScript/PDF to bitmap
- `avahi-daemon` - Enables network printer discovery via mDNS/DNS-SD
- `cups-filters` - Additional filter utilities for CUPS
- `psutils` - PostScript utilities

### 2. Verify Ghostscript Installation
The Brother driver requires Ghostscript to render print jobs:
```bash
gs --version
```

**Expected output:** `10.00.0` or higher

### 3. Add Your User to lpadmin Group
Replace `pi` with your username if different:
```bash
sudo usermod -a -G lpadmin pi
```

**Important:** Log out and back in (or reboot) for group membership changes to take effect.

Verify membership:
```bash
groups
```

You should see `lpadmin` in the output.

---

## Disable Conflicting Services

**CRITICAL:** The `ipp-usb` service can hijack the USB connection, preventing the Brother driver from communicating with the printer. `cups-browsed` can also interfere with printer configuration.

```bash
sudo systemctl stop ipp-usb cups-browsed
sudo systemctl disable ipp-usb cups-browsed
```

**What this does:** Stops and prevents these services from starting on boot, ensuring the Brother driver has direct USB access.

---

## Download & Install Brother Driver

### 1. Download the ARM Driver

**CRITICAL:** The QL-1100 requires the ARMhf version for Raspberry Pi.

```bash
wget https://download.brother.com/welcome/dlfp100581/ql1100pdrv-2.1.4-0.armhf.deb
```

**Verify the download:**
```bash
ls -lh ql1100pdrv-2.1.4-0.armhf.deb
```

You should see a file approximately 50KB in size.

### 2. Install the Driver

```bash
sudo dpkg -i --force-all ql1100pdrv-2.1.4-0.armhf.deb
sudo apt-get -f install
```

**Expected output:**
```
Selecting previously unselected package ql1100pdrv.
(Reading database ... )
Preparing to unpack ql1100pdrv-2.1.4-0.armhf.deb ...
Unpacking ql1100pdrv (2.1.4-0) ...
Setting up ql1100pdrv (2.1.4-0) ...
```

**Note:** The `--force-all` flag may be necessary if the CUPS wrapper script fails ARM dependency checks even though it will work correctly.

### 3. Verify Driver Installation

Check that the critical ARM binary is present and is the correct architecture:
```bash
file /opt/brother/PTouch/ql1100/lpd/rastertobrpt1
```

**Expected output:**
```
/opt/brother/PTouch/ql1100/lpd/rastertobrpt1: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 2.6.32
```

**Important:** This confirms the ARM architecture. Some guides incorrectly state the driver is not available for ARM or is only source code.

### 4. Fix Driver Permissions

Ensure all Brother binaries are executable:

```bash
sudo chmod +x /opt/brother/PTouch/ql1100/lpd/rastertobrpt1
sudo chmod +x /opt/brother/PTouch/ql1100/cupswrapper/brother_lpdwrapper_ql1100
```

**What this does:** Brother Linux drivers often have incorrect permissions by default. This step prevents silent job failures.

### 5. Verify Driver Files

Check that all necessary components are installed:
```bash
ls -l /opt/brother/PTouch/ql1100/lpd/
ls -l /opt/brother/PTouch/ql1100/cupswrapper/
```

You should see:
- `/opt/brother/PTouch/ql1100/lpd/rastertobrpt1` (ARM binary rasterizer)
- `/opt/brother/PTouch/ql1100/lpd/filter_ql1100` (Perl filter script)
- `/opt/brother/PTouch/ql1100/lpd/brpapertoolcups` (Paper tool utility)
- `/opt/brother/PTouch/ql1100/lpd/brother_lpdwrapper_ql1100` (Perl wrapper)
- `/opt/brother/PTouch/ql1100/lpd/cupswrapperql1100` (CUPS wrapper script)
- `/opt/brother/PTouch/ql1100/lpd/brother_ql1100_printer_en.ppd` (PPD file)

---

## Configure the Printer in CUPS

### 1. Connect the Printer
- Connect the Brother QL-1100 to Raspberry Pi via USB
- Power on the printer
- Load DK-1247 labels (103mm x 164mm)

### 2. Verify USB Connection

Find the USB device identifier:
```bash
lsusb | grep Brother
```

**Expected output:**
```
Bus 001 Device 004: ID 04f9:20a7 Brother Industries, Ltd QL-1100 Label Printer
```

The device ID `04f9:20a7` confirms the QL-1100 is recognized.

### 3. Find the USB URI

List available printer URIs:
```bash
lpinfo -v
```

**Look for a line like:**
```
direct usb://Brother/QL-1100?serial=000C5G830123
```

**Note:** Your serial number will be different. Copy this URI for the next step.

### 4. Create the Printer Queue

Restart CUPS to ensure it picks up the new driver files:
```bash
sudo systemctl restart cups
```

Add the printer using the USB URI from step 3 (replace `serial=000C5G830123` with your actual serial):
```bash
sudo lpadmin -p Brother_QL1100 -E \
  -v usb://Brother/QL-1100?serial=000C5G830123 \
  -P /opt/brother/PTouch/ql1100/cupswrapper/brother_ql1100_printer_en.ppd \
  -D "Brother QL-1100 Label Printer" \
  -L "Office"
```

**What the flags mean:**
- `-p Brother_QL1100` - Printer name (use underscores, not spaces)
- `-E` - Enable the printer and accept jobs
- `-v usb://...` - Device URI (replace serial number with yours)
- `-P /opt/...ppd` - PPD file path
- `-D "..."` - Printer description (optional)
- `-L "..."` - Printer location (optional)

### 5. Remove Auto-Discovered Printer Queue

If `ipp-usb` created an auto-discovered printer queue before it was disabled, remove it now:

```bash
sudo lpadmin -x QL-1100
```

**Note:** If you see "lpadmin: Unable to delete printer or class: Not Found", that's fine - it means no auto-discovered queue existed. This step ensures only your properly configured `Brother_QL1100` queue remains.

```bash
sudo systemctl restart cups
```

---

## Lock Default Settings

This is **CRITICAL** to prevent network clients from sending incorrect media sizes or DPI settings that would cause the printer to reject jobs.

**Important Note About Label Sizes:** The rest of this document references `103x164` as the media size. This is correct for **DK-1247** labels (4.07" x 6.4" / 103mm x 164mm Large Shipping White Paper Labels). If you are using a different size label, you will need to change the defaults and update each reference to the appropriate media size:
- `103x164` for DK-1247: 4.07 in x 6.4 in (103 mm x 164 mm) Large Shipping White Paper Labels
- `102x152` for DK-1241: 4 in x 6 in (102 mm x 152 mm) Large Shipping White Paper Labels
- etc.

Make sure your chosen size matches one of the available sizes in the output of:
```bash
lpoptions -p Brother_QL1100 -l | grep Media
```

### 1. Lock Paper Size and Quality

Change the media and PageSize below from 103x164 if needed:
```bash
sudo lpadmin -p Brother_QL1100 -o media=103x164 -o PageSize=103x164 -o BrPriority=BrSpeed -o printer-is-shared=true -o orientation-requested=auto -o fit-to-page=true
```

**What this does:**
- `media=103x164` and `PageSize=103x164` - Forces 103mm x 164mm label size (DK-1247)
- `BrPriority=BrSpeed` - Locks print quality to High Speed mode (300 DPI)
- `printer-is-shared=true` - Enables network sharing
- `orientation-requested=auto` - Auto-rotates the image to fit the page
- `fit-to-page=true` - Automatically scales the image to fit the page

**Why this matters:** Without locked defaults, clients may send incorrect paper sizes like "4x6 inches" (101.6mm x 152.4mm - WRONG) causing print failures.

### 2. Deploy Custom PPD File

If you want to be able to print from an iOS device and have the paper size defaulted correctly for your labels, you need to deploy a modified PPD file to the Raspberry Pi:

**PPD File Edits:**

1. Edit the PPD file `Brother_QL1100.ppd` to set the default media size and comment out unused sizes:

   **Four sections to modify:**
   - `*DefaultPageSize:` - Set default media size
   - `*DefaultPageRegion:` - Set default page region (should match PageSize)
   - `*DefaultImageableArea:` - Set default imageable area
   - `*DefaultPaperDimension:` - Set default paper dimensions

   **Example edits for DK-1247 (103x164mm) labels:**

   ```ppd
   *% Section 1: Default PageSize
   *DefaultPageSize: 103x164
   *OpenUI *PageSize/Media Size: PickOne
   *OrderDependency: 11 AnySetup *PageSize
   *PageSize 103x164/103mm x 164mm(4.07" x 6.4"):	"          "
   *%PageSize 62x100/62mm x 100mm(2.4" x 3.9"):		"          "
   *%PageSize 62x29/62mm x 29mm(2.4" x 1.1"):		"          "
   *CloseUI: *PageSize

   *% Section 2: Default PageRegion
   *DefaultPageRegion: 103x164
   *OpenUI *PageRegion: PickOne
   *OrderDependency: 12 AnySetup *PageRegion
   *PageRegion 103x164/103mm x 164mm(4.07" x 6.4"):	"          "
   *%PageRegion 62x100/62mm x 100mm(2.4" x 3.9"):		"          "
   *%PageRegion 62x29/62mm x 29mm(2.4" x 1.1"):			"          "
   *CloseUI: *PageRegion

   *% Section 3: Default ImageableArea
   *DefaultImageableArea: 103x164
   *ImageableArea 103x164/103mm x 164mm(4.07" x 6.4"):	"2.88 14.17 290.79 451.67"
   *%ImageableArea 62x100/62mm x 100mm(2.4" x 3.9"):	"4.32 8.4   171.36 274.56"
   *%ImageableArea 62x29/62mm x 29mm(2.4" x 1.1"):		"4.32 8.4   171.36 73.44"

   *% Section 4: Default PaperDimension
   *DefaultPaperDimension: 103x164
   *PaperDimension 103x164/103mm x 164mm(4.07" x 6.4"):	"293.67 465.84"
   *%PaperDimension 62x100/62mm x 100mm(2.4" x 3.9"):		"175.68 282.96"
   *%PaperDimension 62x29/62mm x 29mm(2.4" x 1.1"):			"175.68 81.84"
   ```

   **Key points:**
   - Active entries have `*` prefix: `*103x164/103 mm x 164 mm: ...`
   - Commented entries have `*%` prefix: `*%62x100/62 mm x 100 mm: ...`
   - All four `Default*` directives must match your chosen media size
   - Keep at least one size active (uncommented) in each section
   - The default size must be one of the active (uncommented) options

   **Why this matters:** iOS AirPrint clients respect the PPD's default media size. Without this modification, devices may default to incorrect sizes or show unavailable options.

**PPD File Deployment Script Configuration:**

This assumes your Pi is already setup to allow ssh access.

1. Copy the example configuration file:
   ```bash
   cp deploy_config.example.sh deploy_config.sh
   ```

2. Edit `deploy_config.sh` with your Pi's details:
   ```bash
   REMOTE_USER="pi"
   REMOTE_HOST="pi.local"
   ```

**PPD File Deployment:**

1. Make the script executable:
   ```bash
   chmod +x deploy_ppd.sh
   ```

2. Run the deployment:
   ```bash
   ./deploy_ppd.sh
   ```

The script backs up the existing PPD file before replacing it at `/etc/cups/ppd/Brother_QL1100.ppd`.

### 3. Verify Settings

```bash
lpoptions -p Brother_QL1100 -l
```

Expected output should include the quality setting and only the sizes left active:
```
PageSize/Media Size: *103x164 102x152
...
BrPriority/Quality: *BrSpeed BrQuality
...
```

The `*` indicates the default value. Both `103x164` and `BrSpeed` should have asterisks.

**Note:** The default media size settings (e.g., `103x164`) are *named* settings. If you change the names to other values that might be recognized by iOS or other print clients, you might not be able to print, because the Brother printing pipeline expects the exact names to be passed through.

### 4. Restart CUPS

Note that the deploy_ppd.sh script does this for you.
```bash
sudo systemctl restart cups
```

---

## Configure Network Access

Enable remote administration and printer sharing. Network devices will not be able to see the printer until print sharing is enabled, so that setting is necessary. Remote administraiton allows use of the CUPS admin portal on the network but is not necessary to enable.

```bash
sudo cupsctl --remote-admin --remote-any --share-printers
```

**What this does:**
- `--remote-admin` - Allows remote CUPS administration
- `--remote-any` - Allows access from any network interface
- `--share-printers` - Enables printer sharing on the network

### Restart Services

```bash
sudo systemctl restart cups avahi-daemon
```

---

## Testing & Verification

### Test 1: Local Print Test from Raspberry Pi

```bash
echo "Test print from Raspberry Pi $(date)" | lp -d Brother_QL1100
```

**Expected behavior:** Printer should immediately start printing a label with the text and timestamp.

Check job status:
```bash
lpstat -p Brother_QL1100
```

**Expected:** `printer Brother_QL1100 is idle. enabled since [date/time]`

### Test 2: Verify Printer Queue

```bash
lpstat -p     # Check if printer is idle/ready
lpstat -v     # Verify the USB connection
lpstat -e     # List all available printers
```

**Expected output from `lpstat -e`:** You should see `Brother_QL1100` and possibly `Brother_QL_1100_Label_Printer_[hostname]` (this is normal - CUPS discovers its own shared printer via the network). However, if you see an entry like "QL-1100" (without the "Brother_" prefix), this is an unwanted auto-discovered queue from `ipp-usb` that should be removed:

```bash
sudo lpadmin -x QL-1100
sudo systemctl restart cups
```

### Test 3: Network Discovery Test

From another device on your network, verify the printer is advertised:

**macOS/Linux:**
```bash
dns-sd -B _ipp._tcp
```

or

```bash
avahi-browse -rt _ipp._tcp
```

You should see your printer listed.

### Test 4: iOS/macOS (AirPrint)

1. On iPhone/iPad: Open any app → **Share** → **Print** → **Select Printer**
2. Your printer should appear as **Brother_QL1100** or similar
3. On macOS: **System Settings** → **Printers & Scanners** → Click **+**
4. The printer should auto-discover via AirPrint

### Test 5: Windows

1. **Settings** → **Devices** → **Printers & Scanners**
2. Click **Add a printer or scanner**
3. Windows should discover the printer automatically
4. If not: Click **The printer that I want isn't listed** → Enter `http://<raspberry-pi-ip>:631/printers/Brother_QL1100`

---

## Troubleshooting

### Issue: Printer Not Discovered on Network

**Diagnostic:**
```bash
sudo systemctl status cups
sudo systemctl status avahi-daemon
```

Both should show `active (running)`.

**Fix:**
```bash
sudo systemctl restart cups avahi-daemon
```

### Issue: Print Jobs Stuck in Queue

**Check logs:**
```bash
sudo tail -20 /var/log/cups/error_log
```

**Common causes:**
- Wrong media size - verify locked defaults with `lpoptions -p Brother_QL1100 -l`
- Permission issues - re-run `chmod +x` on driver binaries
- USB connection - verify with `lsusb | grep Brother`

### Issue: Printer Rejects Jobs (Red Blinking Light)

**Cause:** Usually incorrect media size or DPI mismatch.

**Fix:**
1. Verify locked defaults: `lpoptions -p Brother_QL1100 -l`
2. Ensure `PageSize` shows `*103x164`
3. Re-run lock command if needed (see [Lock Default Settings](#lock-default-settings))

---

## Additional Resources

- [Brother QL-1100 Official Linux Drivers](https://support.brother.com/g/b/downloadlist.aspx?c=us&lang=en&prod=lpql1100eus&os=127)
- [CUPS Documentation](https://www.cups.org/documentation.html)
- Detailed setup notes: See `brother-ql1100-setup.md`, `setup1.md`, and `setup2.md` in this repository

---

**Author Notes:** This guide consolidates field-tested configurations from multiple Raspberry Pi deployments. All commands have been verified on Raspberry Pi OS Bookworm.