# Touchscreen Driver Solution for OrangeFox Recovery

## 🎯 Problem

OrangeFox recovery builds successfully but **touchscreen doesn't respond**. This is a common issue caused by missing kernel modules (drivers) in the recovery image.

## ✅ Solution

We provide a complete automated solution with 4 scripts and comprehensive documentation to extract touchscreen drivers from your device's boot image and integrate them into recovery.

## 🚀 Quick Start

### Method 1: One Command (Recommended)
```bash
./setup_touchscreen.sh boot.img <device_codename>
```

### Method 2: Step by Step
```bash
# Step 1: Extract modules from boot image
./extract_touch_modules.sh boot.img

# Step 2: Add modules to device tree
./add_modules_to_recovery.sh <device_codename> extracted_modules

# Step 3: Verify setup
./verify_setup.sh <device_codename>

# Step 4: Build recovery
lunch twrp_<device_codename>-eng && mka recoveryimage
```

## 📦 What's Included

### Scripts
| Script | Purpose | Size |
|--------|---------|------|
| `extract_touch_modules.sh` | Extract modules from boot image | 7.4KB |
| `add_modules_to_recovery.sh` | Add modules to device tree | 4.7KB |
| `setup_touchscreen.sh` | All-in-one automated setup | 3.5KB |
| `verify_setup.sh` | Validate setup before building | 5.6KB |

### Documentation
| File | Description | Size |
|------|-------------|------|
| `TOUCHSCREEN_GUIDE.md` | Complete step-by-step guide | 7.3KB |
| `QUICK_REFERENCE.md` | Quick command reference | 3.1KB |
| `IMPLEMENTATION.md` | Technical implementation details | 7.2KB |
| `EXAMPLE_USAGE.txt` | Real-world usage scenarios | 3.4KB |

## 🎯 Supported Devices

All Xiaomi SM8650 devices:
- **aurora** - Xiaomi 14 Ultra
- **chenfeng** - POCO F6 Pro  
- **houji** - Xiaomi 14
- **peridot** - Redmi K70
- **ruyi** - Redmi K70E
- **shennong** - Xiaomi 14 Pro
- **zorn** - Redmi K70 Pro

## 🔧 Features

✅ **Multi-tool support**: Works with magiskboot, unpack_bootimg, or abootimg  
✅ **Smart detection**: Automatically detects device path and configuration  
✅ **Error handling**: Comprehensive validation and helpful error messages  
✅ **Color output**: Easy-to-read colored terminal output  
✅ **Verification**: Built-in setup verification before building  
✅ **Documentation**: Extensive guides with troubleshooting  

## 📖 Documentation

- **Quick Start**: See above or `README.md`
- **Detailed Guide**: [TOUCHSCREEN_GUIDE.md](TOUCHSCREEN_GUIDE.md)
- **Quick Reference**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- **Implementation**: [IMPLEMENTATION.md](IMPLEMENTATION.md)
- **Examples**: [EXAMPLE_USAGE.txt](EXAMPLE_USAGE.txt)

## 🔍 How It Works

```
┌─────────────────┐
│   boot.img      │ ← Your device's boot image (from stock ROM)
└────────┬────────┘
         │
         ▼ extract_touch_modules.sh
┌─────────────────┐
│ Kernel Modules  │ ← Touchscreen .ko files extracted
│  - focaltech    │
│  - goodix       │
│  - synaptics    │
└────────┬────────┘
         │
         ▼ add_modules_to_recovery.sh
┌─────────────────────────┐
│ Device Tree             │ ← Modules added to prebuilts/
│  prebuilts/device/      │   Makefile updated
│  twrp_device.mk         │
└────────┬────────────────┘
         │
         ▼ Build Recovery
┌─────────────────────────┐
│ Recovery Image          │ ← Modules included in recovery
│  - Touchscreen works! ✓ │
└─────────────────────────┘
```

## 🛠️ Prerequisites

You need ONE of these tools installed:
- `magiskboot` (recommended, from Magisk)
- `unpack_bootimg` (from Android SDK)
- `abootimg` (from package manager)

Plus standard tools: `cpio`, `lz4`, `gzip`

### Install on Ubuntu/Debian
```bash
sudo apt-get install android-sdk-libsparse-utils abootimg lz4-tool
```

### Install on Arch Linux
```bash
sudo pacman -S android-tools lz4
yay -S abootimg
```

## 💡 Common Issues

| Problem | Solution |
|---------|----------|
| No modules found | Try `vendor_boot.img` instead |
| Module load fails | Check dependencies with `dmesg` |
| Version mismatch | Extract from same Android version |
| Touch still dead | Verify modules with `verify_setup.sh` |

## 🧪 Verification

After setup, verify everything is correct:

```bash
./verify_setup.sh <device_codename>
```

Expected output:
```
✓ Device directory exists
✓ Modules directory exists
✓ Found 12 kernel module(s)
✓ Device makefile exists
✓ Modules referenced in makefile
✓ All checks passed!
```

## 📝 Example Session

```bash
# Extract from boot image
$ ./extract_touch_modules.sh boot.img
[INFO] Found: focaltech_touch.ko
[INFO] Found: goodix_core.ko
[INFO] Extraction complete! Found 12 module(s)

# Add to device tree
$ ./add_modules_to_recovery.sh aurora extracted_modules
[INFO] Detected DEVICE_PATH: device/xiaomi/sm8650
[INFO] Success! Modules added to device tree

# Verify
$ ./verify_setup.sh aurora
✓ All checks passed!

# Commit and build
$ git add . && git commit -m "Add touchscreen modules"
$ lunch twrp_aurora-eng && mka recoveryimage
```

## 🐛 Troubleshooting

### Script won't run
```bash
chmod +x *.sh  # Make scripts executable
```

### No extraction tool found
```bash
# Install abootimg
sudo apt install abootimg  # Ubuntu/Debian
sudo pacman -S abootimg    # Arch Linux
```

### Modules don't work in recovery
```bash
# Check in recovery via adb
adb shell ls /vendor/lib/modules/
adb shell dmesg | grep -i touch
```

See [TOUCHSCREEN_GUIDE.md](TOUCHSCREEN_GUIDE.md) for detailed troubleshooting.

## 🤝 Contributing

Found a bug or have improvements?
1. Test your changes thoroughly
2. Update documentation if needed
3. Submit a pull request

## 📄 License

Copyright (C) 2025 The TWRP Open Source Project  
Licensed under Apache License 2.0

## 🙏 Credits

- TWRP & OrangeFox Recovery Projects
- Xiaomi SM8650 Device Maintainers
- Community Contributors

## 📞 Support

Need help?
1. Read [TOUCHSCREEN_GUIDE.md](TOUCHSCREEN_GUIDE.md) first
2. Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for commands
3. Review [EXAMPLE_USAGE.txt](EXAMPLE_USAGE.txt) for scenarios
4. Open an issue with complete logs and device info

---

**Made with ❤️ for the Android Recovery Community**
