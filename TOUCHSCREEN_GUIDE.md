# Touchscreen Driver Extraction Guide

This guide explains how to extract touchscreen drivers from your device's boot image and add them to the OrangeFox recovery image to enable touchscreen functionality.

## Problem

OrangeFox recovery builds successfully but the touchscreen doesn't respond. This happens because the kernel modules (drivers) required for touchscreen functionality are not included in the recovery image.

## Solution

We provide two scripts to automate the extraction and integration process:

1. **extract_touch_modules.sh** - Extracts kernel modules from boot/vendor_boot image
2. **add_modules_to_recovery.sh** - Adds extracted modules to your device tree

## Prerequisites

Before starting, you'll need:

- Your device's boot.img or vendor_boot.img file (from stock ROM or current installation)
- One of these tools installed:
  - `magiskboot` (recommended, included in Magisk)
  - `unpack_bootimg` (from Android platform tools)
  - `abootimg` (available via apt/yum)
- Basic command-line tools: `cpio`, `lz4`, `gzip`

### Installing Required Tools

#### On Ubuntu/Debian:
```bash
sudo apt-get install android-sdk-libsparse-utils abootimg lz4-tool
```

#### On Arch Linux:
```bash
sudo pacman -S android-tools lz4
yay -S abootimg
```

#### Installing Magiskboot (recommended):
Download Magisk APK from [GitHub](https://github.com/topjohnwu/Magisk/releases), extract it, and get `magiskboot` from `lib/arm64-v8a/libmagiskboot.so` (rename to `magiskboot`).

## Step-by-Step Guide

### Step 1: Extract Kernel Modules from Boot Image

Run the extraction script with your boot image:

```bash
./extract_touch_modules.sh boot.img
```

Or if your device uses vendor_boot:

```bash
./extract_touch_modules.sh vendor_boot.img
```

You can specify a custom output directory:

```bash
./extract_touch_modules.sh boot.img my_extracted_modules
```

The script will:
- Extract the boot/vendor_boot image
- Search for touchscreen-related kernel modules
- Copy them to the output directory (default: `extracted_modules`)

Expected output:
```
[INFO] Starting touchscreen module extraction from boot.img
[INFO] Found: ./vendor/lib/modules/focaltech_touch.ko
[INFO] Found: ./vendor/lib/modules/goodix_core.ko
...
[INFO] Extraction complete!
[INFO] Found 12 module(s)
```

### Step 2: Add Modules to Device Tree

Once modules are extracted, add them to your device tree:

```bash
./add_modules_to_recovery.sh <device_codename> extracted_modules
```

For example, for the aurora device:

```bash
./add_modules_to_recovery.sh aurora extracted_modules
```

Available device codenames:
- aurora
- chenfeng
- houji
- peridot
- ruyi
- shennong
- zorn

The script will:
- Create a `prebuilts/<device>/modules` directory
- Copy all extracted .ko files there
- Update `twrp_<device>.mk` to include module copy directives

### Step 3: Verify Changes

Check that modules were copied:

```bash
ls -lh prebuilts/<device_codename>/modules/
```

Verify the makefile was updated:

```bash
grep -A2 "modules" twrp_<device_codename>.mk
```

You should see something like:
```makefile
# dependencies (copy kernel modules for touchscreen)
PRODUCT_COPY_FILES += $(call find-copy-subdir-files,*,device/xiaomi/sm8650/prebuilts/<device>/modules,recovery/root/vendor/lib/modules)
```

### Step 4: Rebuild Recovery

Rebuild your recovery image with the included modules:

```bash
# In your TWRP build environment
cd <twrp_source>
. build/envsetup.sh
lunch twrp_<device_codename>-eng
mka recoveryimage
```

Or using GitHub Actions (if you're using the action builder):
1. Push your changes to the device tree repository
2. Trigger the build workflow
3. Download the new recovery image

### Step 5: Test

Flash the new recovery image and test touchscreen functionality:

```bash
fastboot flash recovery recovery.img
fastboot reboot recovery
```

The touchscreen should now be responsive in recovery mode.

## Troubleshooting

### No modules found

**Problem**: The extraction script reports "No modules were extracted"

**Solutions**:
1. Try extracting from `vendor_boot.img` instead of `boot.img`
2. Check if your device uses `init_boot.img` (Android 13+)
3. The drivers might be built into the kernel (not as modules)

### Modules not loading in recovery

**Problem**: Modules are included but touchscreen still doesn't work

**Solutions**:
1. Check `init.recovery.qcom.rc` has the correct module load order
2. Verify dependencies are loaded first (q6_pdr_dlkm, q6_notifier_dlkm, etc.)
3. Check dmesg in recovery for module load errors:
   ```bash
   adb shell dmesg | grep -i "touch\|module"
   ```
4. Ensure module versions match the kernel version in recovery

### Wrong module order

**Problem**: Modules fail to load due to missing dependencies

**Solution**: Edit `recovery/root/init.recovery.qcom.rc` to ensure correct load order:
```
on early-init
    # Audio/DSP dependencies (must load first)
    insmod /vendor/lib/modules/q6_pdr_dlkm.ko
    insmod /vendor/lib/modules/q6_notifier_dlkm.ko
    ...
    # Touchscreen modules (load after dependencies)
    insmod /vendor/lib/modules/focaltech_touch.ko
    insmod /vendor/lib/modules/goodix_core.ko
    ...
```

### Module version mismatch

**Problem**: "Invalid module format" or version mismatch errors

**Solution**: 
- Ensure the boot image is from the same Android version you're building recovery for
- Extract modules from the same kernel version used in your recovery
- Consider building kernel modules from source

## Advanced: Manual Module Extraction

If the scripts don't work for your device, you can extract manually:

### Using magiskboot:
```bash
magiskboot unpack boot.img
magiskboot cpio ramdisk.cpio extract
find . -name "*.ko" -path "*/vendor/lib/modules/*" -exec cp {} modules/ \;
```

### Using unpack_bootimg:
```bash
python3 -m unpack_bootimg --boot_img boot.img --out extracted
lz4 -d extracted/ramdisk ramdisk.cpio
mkdir ramdisk_dir
cd ramdisk_dir
cpio -idm < ../ramdisk.cpio
find . -name "*.ko" -exec cp {} ../modules/ \;
```

## Module Reference

Common touchscreen modules for Xiaomi SM8650 devices:

### Touchscreen Drivers:
- `focaltech_touch.ko` - Focaltech touchscreen
- `goodix_cap.ko` / `goodix_core.ko` - Goodix touchscreen  
- `synaptics_tcm2.ko` - Synaptics touchscreen
- `speed_touch.ko` - Speed touch driver
- `xiaomi_touch.ko` - Xiaomi touch extensions

### Required Dependencies:
- `q6_pdr_dlkm.ko` - Qualcomm Q6 PDR
- `q6_notifier_dlkm.ko` - Q6 notifier
- `snd_event_dlkm.ko` - Sound event handler
- `gpr_dlkm.ko` - GPR driver
- `spf_core_dlkm.ko` - SPF core
- `adsp_loader_dlkm.ko` - ADSP loader

## Support

If you encounter issues:

1. Check the console output for error messages
2. Verify your boot image is valid: `file boot.img`
3. Ensure you have the required tools installed
4. Try extracting from different image files (vendor_boot, init_boot)
5. Open an issue with:
   - Device model and codename
   - Android version
   - Boot image type
   - Complete error output

## Additional Resources

- [TWRP Device Tree Template](https://github.com/TeamWin/android_device_template_twrp)
- [OrangeFox Build Variables](https://gitlab.com/OrangeFox/vendor/recovery/-/blob/fox_12.1/orangefox_build_vars.txt)
- [Android Boot Image Format](https://source.android.com/docs/core/architecture/bootloader/boot-image-header)

## Credits

Created for the Xiaomi SM8650 device family OrangeFox recovery project.
