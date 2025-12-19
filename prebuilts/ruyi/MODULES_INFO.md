# Ruyi Device - Kernel Modules Extracted from vendor_boot

## Source Information

**Stock ROM Version:** 3.0.3.0.WNIMIXM  
**Source Image:** vendor_boot_3.0.3.0.WNIMIXM_stock.img.xz  
**Image Format:** Android Boot Image v4 with VNDRBOOT magic  
**Compression:** LZ4  
**Extraction Date:** 2025-12-19

## Extraction Summary

- **Total Modules Extracted:** 343
- **Total Size:** 64 MB
- **Location:** `prebuilts/ruyi/modules/`

## Modules Included

### Touchscreen Related
- `goodix_cap.ko` - Goodix capacitive touchscreen driver

### System and Hardware Support
All 343 kernel modules from the vendor_boot partition have been extracted and vendored into this repository. These modules provide comprehensive hardware support for the Redmi K70E (ruyi) device including:

- Display and Graphics (DRM, GPU)
- Storage (UFS)
- Networking (WiFi, Cellular)
- Audio
- Camera
- Sensors
- Power Management
- Security
- And many more...

## Integration

The modules are integrated into the recovery image via `twrp_ruyi.mk`:

```makefile
PRODUCT_COPY_FILES += $(call find-copy-subdir-files,*,\
    device/xiaomi/sm8650/prebuilts/ruyi/modules,\
    recovery/root/vendor/lib/modules)
```

## Module Loading

Modules specified in `recovery/root/init.recovery.qcom.rc` will be loaded at boot:

```rc
on early-init
    insmod /vendor/lib/modules/q6_pdr_dlkm.ko
    insmod /vendor/lib/modules/q6_notifier_dlkm.ko
    insmod /vendor/lib/modules/snd_event_dlkm.ko
    insmod /vendor/lib/modules/gpr_dlkm.ko
    insmod /vendor/lib/modules/spf_core_dlkm.ko
    insmod /vendor/lib/modules/adsp_loader_dlkm.ko
    insmod /vendor/lib/modules/focaltech_touch.ko
    insmod /vendor/lib/modules/goodix_cap.ko
    insmod /vendor/lib/modules/goodix_core.ko
    insmod /vendor/lib/modules/synaptics_tcm2.ko
    insmod /vendor/lib/modules/speed_touch.ko
    insmod /vendor/lib/modules/xiaomi_touch.ko
```

**Note:** Not all modules listed in init.recovery.qcom.rc are present in this vendor_boot extraction. The goodix_cap.ko module is available, but other touchscreen drivers like focaltech_touch.ko, synaptics_tcm2.ko, speed_touch.ko, and xiaomi_touch.ko were not found in this particular stock image.

## Missing Touchscreen Modules

The following touchscreen modules referenced in init.recovery.qcom.rc are NOT present in this vendor_boot:
- focaltech_touch.ko
- goodix_core.ko  
- synaptics_tcm2.ko
- speed_touch.ko
- xiaomi_touch.ko

These modules may be:
1. Device-specific and only present on certain variants
2. Located in a different partition (vendor_dlkm)
3. Built into the kernel rather than as loadable modules
4. Not used by the ruyi device

## Extraction Method

Modules were extracted using a combination of:
1. Detecting VNDRBOOT magic in vendor_boot image
2. Extracting LZ4 compressed data from offset 4096
3. Decompressing with `lz4 -d`
4. Extracting CPIO archive
5. Copying all .ko files from `lib/modules/`

## Tools Used

- `lz4` - LZ4 decompression
- `cpio` - CPIO archive extraction
- Python 3 - Image parsing and extraction orchestration

## Verification

Run the verification script to confirm module integration:

```bash
./verify_setup.sh ruyi
```

Expected output:
```
✓ Device directory exists: prebuilts/ruyi
✓ Modules directory exists: prebuilts/ruyi/modules
✓ Found 343 kernel module(s)
✓ Device makefile exists: twrp_ruyi.mk
✓ Modules referenced in makefile
✓ All checks passed!
```

## Building Recovery with Modules

After vendoring these modules, rebuild recovery:

```bash
cd $TWRP_SOURCE
. build/envsetup.sh
lunch twrp_ruyi-eng
mka recoveryimage
```

The resulting recovery image will include all 343 kernel modules in `/vendor/lib/modules/`.

## License

These kernel modules are proprietary binary files from Xiaomi's stock ROM and are subject to their respective licenses. They are provided here for use in custom recovery images for the Redmi K70E device.

## See Also

- [EXTRACTING_FROM_STOCK.md](EXTRACTING_FROM_STOCK.md) - Guide for extracting from vendor_boot
- [TOUCHSCREEN_GUIDE.md](TOUCHSCREEN_GUIDE.md) - Comprehensive touchscreen fix guide
- [extract_from_vendor_boot.sh](extract_from_vendor_boot.sh) - Extraction script
