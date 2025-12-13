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

If your OrangeFox recovery builds but the touchscreen doesn't respond, you need to extract touchscreen drivers from your boot image and add them to the recovery.

📖 **See [TOUCHSCREEN_GUIDE.md](TOUCHSCREEN_GUIDE.md) for detailed instructions**

Quick start:
```bash
# 1. Extract modules from boot image
./extract_touch_modules.sh boot.img

# 2. Add modules to device tree
./add_modules_to_recovery.sh <device_codename> extracted_modules

# 3. Rebuild recovery
```
