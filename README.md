# OrangeFox Action Builder
Compile your first custom recovery from OrangeFox Recovery using Github Action.

# How to Use
1. Fork this repository.

2. Go to `Action` tab > `All workflows` > `OrangeFox - Build` > `Run workflow`, then fill all the required information:
 * MANIFEST_BRANCH (`12.1` and `11.0`)
 * DEVICE_TREE (Your device tree repository link.)
 * DEVICE_TREE_BRANCH (Your device tree repository branch.)
 * DEVICE_PATH (`device/vendor/codename`)
 * DEVICE_NAME (Your device codename)
 * BUILD_TARGET (`boot`, `recovery`, `vendorboot`)

 # Note
* This action will now only support manifest 12.1 and 11.0, since all orangefox manifest below 11.0 are considered obsolete.
* Make sure your tree uses right variable (updated vars) from OrangeFox; [fox_11.0](https://gitlab.com/OrangeFox/vendor/recovery/-/blob/fox_11.0/orangefox_build_vars.txt) and [fox_12.1](https://gitlab.com/OrangeFox/vendor/recovery/-/blob/fox_12.1/orangefox_build_vars.txt), to avoid build erros.

# Touchscreen Issues?

If your OrangeFox recovery builds but the touchscreen doesn't respond, you need to extract touchscreen drivers and add them to the recovery.

📖 **See [TOUCHSCREEN_GUIDE.md](TOUCHSCREEN_GUIDE.md) for detailed instructions**

Quick start:

**Option 1: Extract from connected device (Easiest)**
```bash
# Connect device via ADB and run:
./extract_from_device.sh <device_codename>
./add_modules_to_recovery.sh <device_codename> prebuilts/<device_codename>/modules
```

**Option 2: Extract from vendor_boot image (Modern devices)**
```bash
./extract_from_vendor_boot.sh vendor_boot.img extracted_modules <device_codename>
```

**Option 3: Extract from boot image (Older format)**
```bash
./extract_touch_modules.sh boot.img
./add_modules_to_recovery.sh <device_codename> extracted_modules
```

**Option 4: Extract from stock ROM**
See [EXTRACTING_FROM_STOCK.md](EXTRACTING_FROM_STOCK.md) for modern boot image formats (v4)

**Option 5: Patch existing recovery image**
```bash
./patch_recovery_modules.sh recovery.img prebuilts/<device>/modules recovery_patched.img
```
See [PATCHING_GUIDE.md](PATCHING_GUIDE.md) for details

Then verify and rebuild:
```bash
./verify_setup.sh <device_codename>
# Rebuild recovery
```

## Recovery Image Too Large?

If your recovery image exceeds the partition size limit, use the minimal module set:

📖 **See [IMAGE_SIZE_MANAGEMENT.md](IMAGE_SIZE_MANAGEMENT.md) for solutions**

The ruyi device uses a minimal module set (8 modules, 7.5MB) instead of all 343 modules (62MB) to avoid partition size issues. See the guide for customizing which modules to include.

## FBE Decryption (File-Based Encryption)

This device tree includes support for decrypting `/data` partition with File-Based Encryption (FBE).

**Features:**
* Full FBE decryption support for Android 14+
* Qualcomm hardware-backed encryption (ICE - Inline Crypto Engine)
* Metadata partition decryption
* Wrapped key support

The recovery will automatically prompt for your PIN/Password/Pattern to decrypt the data partition when booting into recovery mode.
