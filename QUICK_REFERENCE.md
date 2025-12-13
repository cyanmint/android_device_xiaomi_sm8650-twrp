# Quick Reference: Touchscreen Driver Integration

## One-Command Solution

```bash
# Extract and add in one go (for aurora device example)
./extract_touch_modules.sh boot.img modules_temp && \
./add_modules_to_recovery.sh aurora modules_temp
```

## Individual Steps

### 1. Extract Modules
```bash
./extract_touch_modules.sh <boot_image> [output_dir]

# Examples:
./extract_touch_modules.sh boot.img                    # Extract to extracted_modules/
./extract_touch_modules.sh vendor_boot.img modules/    # Extract to modules/
./extract_touch_modules.sh init_boot.img               # For Android 13+
```

### 2. Add to Device Tree
```bash
./add_modules_to_recovery.sh <device_codename> <modules_dir>

# Examples:
./add_modules_to_recovery.sh aurora extracted_modules
./add_modules_to_recovery.sh peridot modules
./add_modules_to_recovery.sh ruyi /path/to/modules
```

## Device Codenames

| Device | Codename |
|--------|----------|
| Xiaomi 14 | houji |
| Xiaomi 14 Pro | shennong |
| Xiaomi 14 Ultra | aurora |
| Redmi K70 | peridot |
| Redmi K70 Pro | zorn |
| Redmi K70E | ruyi |
| POCO F6 Pro | chenfeng |

## Required Files

**Before running scripts, you need:**
- boot.img or vendor_boot.img (from stock ROM or extracted from device)

**Where to get boot images:**
1. Extract from stock ROM zip
2. Pull from device: `adb pull /dev/block/by-name/boot boot.img`
3. Download from ROM provider (Xiaomi, MIUI, HyperOS)

## Troubleshooting Quick Fixes

| Problem | Solution |
|---------|----------|
| "magiskboot not found" | Install Magisk or use `abootimg` |
| "No modules extracted" | Try vendor_boot.img instead |
| "Device not found" | Check available devices: `ls prebuilts/` |
| Touchscreen still dead | Check `adb shell dmesg` for errors |

## Module Load Order (in init.recovery.qcom.rc)

```rc
on early-init
    # Dependencies first
    insmod /vendor/lib/modules/q6_pdr_dlkm.ko
    insmod /vendor/lib/modules/q6_notifier_dlkm.ko
    insmod /vendor/lib/modules/snd_event_dlkm.ko
    insmod /vendor/lib/modules/gpr_dlkm.ko
    insmod /vendor/lib/modules/spf_core_dlkm.ko
    insmod /vendor/lib/modules/adsp_loader_dlkm.ko
    
    # Touch drivers last
    insmod /vendor/lib/modules/focaltech_touch.ko
    insmod /vendor/lib/modules/goodix_cap.ko
    insmod /vendor/lib/modules/goodix_core.ko
    insmod /vendor/lib/modules/synaptics_tcm2.ko
    insmod /vendor/lib/modules/speed_touch.ko
    insmod /vendor/lib/modules/xiaomi_touch.ko
```

## Verify Installation

```bash
# Check modules are copied
ls -lh prebuilts/<device>/modules/

# Check makefile updated  
grep "modules" twrp_<device>.mk

# Check in recovery after flashing
adb shell ls /vendor/lib/modules/
adb shell dmesg | grep -i touch
```

## Common Module Names

**Touchscreen:**
- focaltech_touch.ko, goodix_core.ko, goodix_cap.ko
- synaptics_tcm2.ko, speed_touch.ko, xiaomi_touch.ko

**Dependencies:**
- q6_pdr_dlkm.ko, q6_notifier_dlkm.ko, adsp_loader_dlkm.ko
- gpr_dlkm.ko, spf_core_dlkm.ko, snd_event_dlkm.ko

---

For detailed information, see [TOUCHSCREEN_GUIDE.md](TOUCHSCREEN_GUIDE.md)
