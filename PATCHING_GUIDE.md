# Recovery Module Patching Guide

## Overview

The `patch_recovery_modules.sh` script allows you to add kernel modules to an already-built recovery image without needing to rebuild from source.

## Use Cases

- You have a pre-built OrangeFox/TWRP recovery but touchscreen doesn't work
- You want to add modules to someone else's recovery build
- You don't have access to the build environment
- Quick testing of module additions

## Prerequisites

**Required Tools:**
- Python 3
- `lz4` - For LZ4 compression/decompression
- `cpio` - For ramdisk archive handling
- `gzip` - For gzip compression (if needed)

**Install on Ubuntu/Debian:**
```bash
sudo apt-get install python3 lz4 cpio gzip
```

## Usage

### Basic Syntax

```bash
./patch_recovery_modules.sh <input_recovery> <modules_directory> <output_recovery>
```

### Arguments

| Argument | Description |
|----------|-------------|
| `input_recovery` | Path to original recovery image (e.g., `recovery.img`) |
| `modules_directory` | Directory containing `.ko` kernel modules to add |
| `output_recovery` | Path where patched recovery will be saved |

## Examples

### Example 1: Patch with All Ruyi Modules

```bash
./patch_recovery_modules.sh \
    OrangeFox-recovery.img \
    prebuilts/ruyi/modules \
    OrangeFox-recovery-patched.img
```

### Example 2: Patch with Specific Modules

```bash
# Create directory with only needed modules
mkdir touchscreen_modules
cp prebuilts/ruyi/modules/goodix_cap.ko touchscreen_modules/
cp prebuilts/ruyi/modules/synaptics_tcm2.ko touchscreen_modules/

# Patch recovery
./patch_recovery_modules.sh \
    recovery.img \
    touchscreen_modules \
    recovery-with-touch.img
```

### Example 3: Patch Downloaded Recovery

```bash
# Download OrangeFox recovery
wget https://github.com/user/repo/releases/download/v1/recovery.img

# Patch with vendored modules
./patch_recovery_modules.sh \
    recovery.img \
    prebuilts/ruyi/modules \
    recovery_patched.img

# Flash to device
fastboot flash recovery recovery_patched.img
```

## How It Works

### Step-by-Step Process

1. **Unpack Recovery Image**
   - Reads Android Boot Image header
   - Identifies ramdisk location (typically at offset 4096)
   - Detects compression type (LZ4, gzip, or uncompressed)

2. **Decompress Ramdisk**
   - Uses appropriate decompression tool
   - Extracts CPIO archive
   - Creates temporary ramdisk directory

3. **Add Modules**
   - Creates `/vendor/lib/modules/` directory in ramdisk
   - Copies all `.ko` files from source directory
   - Preserves file permissions

4. **Repack Ramdisk**
   - Creates new CPIO archive with added modules
   - Compresses using original compression method
   - Maintains compatibility with original format

5. **Rebuild Recovery**
   - Combines original header with new ramdisk
   - Creates new recovery image
   - Preserves boot image structure

### Directory Structure After Patching

```
recovery.img (patched)
├── boot header (preserved)
└── ramdisk (modified)
    └── vendor/
        └── lib/
            └── modules/
                ├── goodix_cap.ko (added)
                ├── synaptics_tcm2.ko (added)
                └── ... (343 modules)
```

## Supported Image Formats

- Android Boot Image v3
- Android Boot Image v4
- Compressions: LZ4, gzip, uncompressed
- Recovery images from TWRP, OrangeFox, etc.

## Limitations

- **Boot images only**: Works with boot/recovery images, not vendor_boot
- **Ramdisk size**: May increase recovery size significantly (343 modules = ~64MB)
- **Partition size**: Ensure recovery partition is large enough
- **Module compatibility**: Modules must match kernel version in recovery

## Verification

After patching, verify the modules were added:

### Method 1: Boot into Recovery and Check

```bash
# Boot patched recovery
fastboot boot recovery_patched.img

# Or flash it
fastboot flash recovery recovery_patched.img
fastboot reboot recovery

# Check via ADB
adb shell ls /vendor/lib/modules/
```

Expected output:
```
goodix_cap.ko
cfg80211.ko
... (all 343 modules)
```

### Method 2: Extract and Inspect

```bash
# Extract patched recovery
mkdir verify
cd verify
dd if=../recovery_patched.img bs=1 skip=4096 | lz4 -d | cpio -idm

# Check modules
ls -lh vendor/lib/modules/
```

## Troubleshooting

### Issue: "Failed to decompress ramdisk"

**Cause**: Unsupported compression format or corrupted image

**Solutions**:
- Verify image is valid: `file recovery.img`
- Check image format: `xxd recovery.img | head -20`
- Ensure lz4 tool is installed

### Issue: "Recovery partition too small"

**Cause**: Added modules exceed partition size

**Symptoms**: Flash fails or device won't boot

**Solutions**:
1. Use fewer modules (only touchscreen-related)
2. Check partition size: `fastboot getvar partition-size:recovery`
3. Compare image sizes: `ls -lh recovery*.img`

### Issue: "Modules don't load in recovery"

**Cause**: Module version mismatch or missing dependencies

**Solutions**:
1. Check kernel version: `adb shell cat /proc/version`
2. Verify module compatibility
3. Check dmesg for errors: `adb shell dmesg | grep ko`
4. Ensure init.rc loads modules correctly

### Issue: "Device won't boot after flashing"

**Cause**: Corrupted recovery image or incompatible modification

**Solutions**:
1. **Immediate**: Flash original recovery
2. Verify patched image size isn't corrupted
3. Try patching again with fewer modules
4. Check boot logs if accessible

## Advanced Usage

### Patch Multiple Images

```bash
# Patch for different devices
for device in aurora peridot ruyi; do
    ./patch_recovery_modules.sh \
        recovery_${device}.img \
        prebuilts/${device}/modules \
        recovery_${device}_patched.img
done
```

### Selective Module Addition

```bash
# Script to add only touchscreen modules
mkdir /tmp/touch_modules
for module in goodix_cap.ko focaltech_touch.ko synaptics_tcm2.ko xiaomi_touch.ko; do
    [ -f "prebuilts/ruyi/modules/$module" ] && \
        cp "prebuilts/ruyi/modules/$module" /tmp/touch_modules/
done

./patch_recovery_modules.sh recovery.img /tmp/touch_modules recovery_touch.img
```

### Automation Script

```bash
#!/bin/bash
# auto_patch.sh - Automated recovery patching

RECOVERY_URL="https://example.com/recovery.img"
DEVICE="ruyi"

# Download recovery
wget $RECOVERY_URL -O recovery_original.img

# Patch with modules
./patch_recovery_modules.sh \
    recovery_original.img \
    prebuilts/$DEVICE/modules \
    recovery_patched.img

# Flash
fastboot flash recovery recovery_patched.img
fastboot reboot recovery

echo "Patched recovery flashed. Test touchscreen!"
```

## Safety Notes

⚠️ **Important Warnings:**

1. **Backup**: Always keep original recovery image
2. **Test First**: Use `fastboot boot` before `fastboot flash`
3. **Match Versions**: Ensure modules match recovery kernel version
4. **Partition Size**: Verify patched image fits in partition
5. **Reversible**: Keep original to restore if needed

## When to Use This vs Building from Source

| Scenario | Use Patching | Build from Source |
|----------|--------------|-------------------|
| Quick test | ✅ Yes | ❌ No |
| No build environment | ✅ Yes | ❌ No |
| Pre-built recovery | ✅ Yes | ❌ No |
| Custom modifications | ❌ No | ✅ Yes |
| Official release | ❌ No | ✅ Yes |
| Learning/Development | ❌ No | ✅ Yes |

## See Also

- [TOUCHSCREEN_GUIDE.md](TOUCHSCREEN_GUIDE.md) - Complete touchscreen fix guide
- [extract_from_vendor_boot.sh](extract_from_vendor_boot.sh) - Extract modules from vendor_boot
- [EXTRACTING_FROM_STOCK.md](EXTRACTING_FROM_STOCK.md) - Modern boot image guide
- [verify_setup.sh](verify_setup.sh) - Verify module setup before building

## Credits

This script automates the manual process of unpacking, modifying, and repacking Android boot images for recovery module injection.
