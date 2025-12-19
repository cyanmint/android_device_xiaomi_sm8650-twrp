# Extracting Kernel Modules from Stock Images

## Challenge with Modern Boot Images

The stock images provided (boot_3.0.3.0.WNIMIXM_stock.img, init_boot_3.0.3.0.WNIMIXM_stock.img, recovery_3.0.3.0.WNIMIXM_stock.img) use Android Boot Image Header Version 4, which has a different structure than older boot images.

In these modern images:
- Kernel modules are typically NOT in boot.img or recovery.img
- Modules are usually in vendor_dlkm or system_dlkm partitions
- The ramdisk in these images may be minimal or vendor-specific

## Alternative Methods to Get Kernel Modules

### Method 1: Extract from Running Device (Recommended)

If you have access to a working device with the stock ROM:

```bash
# Connect device via ADB with USB debugging enabled
adb devices

# Extract modules from device
./extract_from_device.sh ruyi
```

This will pull all required kernel modules from `/vendor/lib/modules/` on the device.

### Method 2: Extract from Full Stock ROM

Download the complete stock ROM (MIUI/HyperOS firmware) which includes all partitions:

1. Download full ROM from Xiaomi or ROM provider
2. Extract vendor_dlkm.img or vendor.img from the ROM
3. Mount the image:
   ```bash
   mkdir vendor_mount
   sudo mount -o loop,ro vendor_dlkm.img vendor_mount
   cp vendor_mount/lib/modules/*.ko prebuilts/ruyi/modules/
   sudo umount vendor_mount
   ```

### Method 3: Extract from OTA Package

If you have access to an OTA update package:

1. Extract the OTA zip file
2. Look for vendor_dlkm or vendor partition images
3. Extract modules from those images

### Method 4: Get from Device via TWRP/Recovery

Boot into TWRP/recovery and extract:

```bash
adb shell mount /vendor
adb pull /vendor/lib/modules/ prebuilts/ruyi/modules/
```

## Required Modules

For touchscreen functionality, you need these modules:

**Touchscreen Drivers:**
- focaltech_touch.ko
- goodix_cap.ko
- goodix_core.ko
- synaptics_tcm2.ko
- speed_touch.ko
- xiaomi_touch.ko

**Dependencies:**
- q6_pdr_dlkm.ko
- q6_notifier_dlkm.ko
- snd_event_dlkm.ko
- gpr_dlkm.ko
- spf_core_dlkm.ko
- adsp_loader_dlkm.ko

## What About the Stock Images Provided?

The stock images (boot, init_boot, recovery) from the release:
- **boot.img** - Contains the kernel but not modules (GKI - Generic Kernel Image)
- **init_boot.img** - Contains initial ramdisk, typically no modules
- **recovery.img** - Stock recovery, may not have vendor modules

Modern Android uses GKI (Generic Kernel Image) where modules are separated into dedicated partitions like vendor_dlkm.

## Next Steps

Once you have the kernel modules:

1. Place them in `prebuilts/<device>/modules/`
2. Update device makefile:
   ```bash
   ./add_modules_to_recovery.sh ruyi prebuilts/ruyi/modules
   ```
3. Verify setup:
   ```bash
   ./verify_setup.sh ruyi
   ```
4. Rebuild recovery

## For Repository Maintainers

If you're vendoring modules into the repository:
1. Extract modules using one of the methods above
2. Commit them to `prebuilts/<device>/modules/`
3. Ensure the device makefile includes the PRODUCT_COPY_FILES directive
4. Test the recovery build to ensure touchscreen works

## Technical Details

### Android Boot Image v4 Structure
```
+-----------------+
| Boot Header v4  |  (not v3 or earlier)
+-----------------+
| Kernel          |  (no modules, GKI)
+-----------------+
| Ramdisk         |  (minimal, no vendor modules)
+-----------------+
| Boot Signature  |
+-----------------+
```

### Where Modules Actually Live
```
vendor_dlkm.img          → /vendor_dlkm/lib/modules/*.ko
vendor.img               → /vendor/lib/modules/*.ko
system_dlkm.img          → /system_dlkm/lib/modules/*.ko (less common)
```

## References

- [Android Boot Image Format](https://source.android.com/docs/core/architecture/bootloader/boot-image-header)
- [Generic Kernel Image (GKI)](https://source.android.com/docs/core/architecture/kernel/generic-kernel-image)
- [Dynamic Loadable Kernel Modules (DLKM)](https://source.android.com/docs/core/architecture/kernel/loadable-kernel-modules)
