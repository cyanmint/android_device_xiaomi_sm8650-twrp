# Recovery Image Size Management

## Problem

The recovery partition has a fixed size limit (typically 64MB - 100MB). Including all 343 kernel modules (62MB) may cause the recovery image to exceed this limit, resulting in:
- Flash failures
- Boot failures
- "Image too large" errors

## Solution: Minimal Module Set

Use only essential modules required for touchscreen and basic recovery functionality.

### Size Comparison

| Module Set | Module Count | Size | Use Case |
|------------|--------------|------|----------|
| **Minimal** (recommended) | 8 | ~7.5MB | Touchscreen + essential hardware |
| **Full** | 343 | ~62MB | Complete hardware support (may be too large) |

## Minimal Module Set

The minimal set includes only critical modules:

### Touchscreen
- `goodix_cap.ko` (129KB) - Goodix touchscreen driver

### Essential System
- `binder_gki.ko` (94KB) - Android IPC (required for services)
- `msm_drm.ko` (5.9MB) - Display/graphics support
- `qcom-spmi-pmic.ko` (29KB) - Power management
- `pinctrl-spmi-gpio.ko` (56KB) - GPIO control

### Hardware Communication
- `i2c-msm-geni.ko` (128KB) - I2C bus (touchscreen uses this)
- `spi-msm-geni.ko` (115KB) - SPI bus (some touchscreens)
- `ufs_qcom.ko` (1.1MB) - Storage support

**Total: ~7.5MB** - Safe for most recovery partitions

## Configuration

### Current Setup (Ruyi Device)

The `twrp_ruyi.mk` is configured to use minimal modules by default:

```makefile
# Use minimal set to keep recovery image size small (7.5MB vs 62MB)
PRODUCT_COPY_FILES += $(call find-copy-subdir-files,*,\
    device/xiaomi/sm8650/prebuilts/ruyi/modules_minimal,\
    recovery/root/vendor/lib/modules)
```

### Switch to Full Modules

If your recovery partition is large enough and you need all modules:

```makefile
# Change modules_minimal to modules
PRODUCT_COPY_FILES += $(call find-copy-subdir-files,*,\
    device/xiaomi/sm8650/prebuilts/ruyi/modules,\
    recovery/root/vendor/lib/modules)
```

## Creating Custom Minimal Sets

Use the provided script to create your own minimal module set:

```bash
./create_minimal_modules.sh <device> <source_dir> <output_dir>
```

### Example: Custom Module Selection

```bash
# Start with minimal set
mkdir -p prebuilts/ruyi/modules_custom
cp prebuilts/ruyi/modules_minimal/* prebuilts/ruyi/modules_custom/

# Add specific modules you need
cp prebuilts/ruyi/modules/cfg80211.ko prebuilts/ruyi/modules_custom/  # WiFi
cp prebuilts/ruyi/modules/qcom_sysmon.ko prebuilts/ruyi/modules_custom/  # System monitoring

# Check total size
du -sh prebuilts/ruyi/modules_custom/

# Update makefile to use custom set
sed -i 's|modules_minimal|modules_custom|g' twrp_ruyi.mk
```

## Checking Recovery Partition Size

### Method 1: From Device
```bash
# Boot to fastboot
adb reboot bootloader

# Check partition size
fastboot getvar partition-size:recovery
```

Expected output: `partition-size:recovery: 0x6000000` (96MB in this case)

### Method 2: Check Built Image
```bash
# After building
ls -lh out/target/product/*/recovery.img

# Compare with partition size
# Image must be smaller than partition
```

### Method 3: From Stock ROM
```bash
# Extract partition layout
unzip stock_rom.zip recovery.img
ls -lh recovery.img
```

## Reducing Image Size Further

If minimal modules still exceed partition size:

### 1. Remove Non-Essential Modules

Edit `create_minimal_modules.sh` and remove from `USEFUL_MODULES`:

```bash
# Comment out modules you don't need
# USEFUL_MODULES=(
#     "qcom-spmi-pmic.ko"       # Can remove if not needed
#     "pinctrl-spmi-gpio.ko"    # Can remove if not needed
#     "ufs_qcom.ko"             # Keep if using device storage
# )
```

### 2. Keep Only Touchscreen Module

Absolute minimum for touchscreen only:

```bash
mkdir -p prebuilts/ruyi/modules_touch_only
cp prebuilts/ruyi/modules/goodix_cap.ko prebuilts/ruyi/modules_touch_only/
# Only 129KB!
```

Update makefile:
```makefile
PRODUCT_COPY_FILES += $(call find-copy-subdir-files,*,\
    device/xiaomi/sm8650/prebuilts/ruyi/modules_touch_only,\
    recovery/root/vendor/lib/modules)
```

### 3. Compress Recovery Image

Some devices support compressed recovery images. Check your device's bootloader capabilities.

## Troubleshooting

### Error: "Image too large for partition"

**Cause**: Recovery image exceeds partition size

**Solutions**:
1. Use minimal modules instead of full
2. Remove unnecessary modules
3. Check partition size: `fastboot getvar partition-size:recovery`
4. Reduce other recovery components if possible

### Error: "Touchscreen not working with minimal modules"

**Cause**: Required module missing or dependency issue

**Solutions**:
1. Check which touchscreen your device uses:
   ```bash
   adb shell dmesg | grep -i touch
   ```
2. Add the specific touchscreen module to minimal set
3. Check module dependencies in kernel logs
4. Try adding ADSP/audio modules (some touchscreens need these)

### Error: "Module load failed"

**Cause**: Missing dependencies or version mismatch

**Solutions**:
1. Check dmesg for specific error:
   ```bash
   adb shell dmesg | grep -i "module\|ko"
   ```
2. Add dependency modules mentioned in error
3. Verify modules match kernel version

## Best Practices

### 1. Start Minimal
- Begin with minimal module set
- Test touchscreen functionality
- Add modules only if needed

### 2. Test Before Deploying
```bash
# Build with minimal modules
lunch twrp_ruyi-eng && mka recoveryimage

# Check image size
ls -lh out/target/product/ruyi/recovery.img

# Test boot without flashing
fastboot boot out/target/product/ruyi/recovery.img

# If works, then flash
fastboot flash recovery out/target/product/ruyi/recovery.img
```

### 3. Document Custom Changes
If you create a custom module set, document which modules you included and why in:
```
prebuilts/<device>/MODULES_CUSTOM.md
```

## Module Selection Guidelines

### Always Include
- Touchscreen driver for your device
- `binder_gki.ko` (Android services)
- `msm_drm.ko` (display)

### Include if Needed
- Storage modules (UFS/eMMC) if accessing /data or /sdcard
- I2C/SPI if touchscreen requires it
- WiFi modules if using adb over WiFi

### Usually Not Needed in Recovery
- Camera modules
- Audio modules (except ADSP if touchscreen needs it)
- Bluetooth modules
- Cellular/modem modules
- Sensor modules

## See Also

- [prebuilts/ruyi/MODULES_INFO.md](prebuilts/ruyi/MODULES_INFO.md) - Full module list
- [create_minimal_modules.sh](create_minimal_modules.sh) - Module selection script
- [PATCHING_GUIDE.md](PATCHING_GUIDE.md) - Patching existing images
- [TOUCHSCREEN_GUIDE.md](TOUCHSCREEN_GUIDE.md) - Complete touchscreen guide
