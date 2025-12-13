#!/bin/bash
#
# Script to extract touchscreen kernel modules from boot/vendor_boot image
# Copyright (C) 2025 The TWRP Open Source Project
#
# Usage: ./extract_touch_modules.sh <boot_image> [output_dir]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if boot image is provided
if [ -z "$1" ]; then
    print_error "Usage: $0 <boot_image> [output_dir]"
    echo ""
    echo "Example: $0 boot.img extracted_modules"
    echo "         $0 vendor_boot.img prebuilts/aurora/modules"
    exit 1
fi

BOOT_IMAGE="$1"
OUTPUT_DIR="${2:-extracted_modules}"
TEMP_DIR=$(mktemp -d)

# Check if boot image exists
if [ ! -f "$BOOT_IMAGE" ]; then
    print_error "Boot image not found: $BOOT_IMAGE"
    exit 1
fi

print_info "Starting touchscreen module extraction from $BOOT_IMAGE"
print_info "Output directory: $OUTPUT_DIR"
print_info "Temporary directory: $TEMP_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Cleanup function
cleanup() {
    print_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Check for required tools
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        print_error "Required tool '$1' is not installed"
        return 1
    fi
    return 0
}

# Try to detect and use available tools
UNPACK_TOOL=""
if check_tool magiskboot; then
    UNPACK_TOOL="magiskboot"
    print_info "Using magiskboot for extraction"
elif check_tool unpack_bootimg; then
    UNPACK_TOOL="unpack_bootimg"
    print_info "Using unpack_bootimg for extraction"
elif check_tool abootimg; then
    UNPACK_TOOL="abootimg"
    print_info "Using abootimg for extraction"
else
    print_warn "No boot image unpacker found, will try manual extraction methods"
fi

cd "$TEMP_DIR"

# Function to extract ramdisk
extract_ramdisk() {
    local image="$1"
    
    if [ "$UNPACK_TOOL" = "magiskboot" ]; then
        print_info "Extracting with magiskboot..."
        magiskboot unpack "$image"
        if [ -f "ramdisk.cpio" ]; then
            print_info "Decompressing ramdisk..."
            magiskboot cpio ramdisk.cpio extract
            return 0
        fi
    elif [ "$UNPACK_TOOL" = "unpack_bootimg" ]; then
        print_info "Extracting with unpack_bootimg..."
        python3 -m unpack_bootimg --boot_img "$image" --out .
        if [ -f "ramdisk" ]; then
            print_info "Decompressing ramdisk..."
            # Try different decompression methods
            if file ramdisk | grep -q "gzip"; then
                gunzip -c ramdisk > ramdisk.cpio
            elif file ramdisk | grep -q "LZ4"; then
                lz4 -d ramdisk ramdisk.cpio
            elif file ramdisk | grep -q "XZ"; then
                unxz -c ramdisk > ramdisk.cpio
            else
                mv ramdisk ramdisk.cpio
            fi
            mkdir -p ramdisk_extracted
            cd ramdisk_extracted
            cpio -idm < ../ramdisk.cpio 2>/dev/null || true
            cd ..
            return 0
        fi
    elif [ "$UNPACK_TOOL" = "abootimg" ]; then
        print_info "Extracting with abootimg..."
        abootimg -x "$image"
        if [ -f "initrd.img" ]; then
            print_info "Decompressing ramdisk..."
            mkdir -p ramdisk_extracted
            cd ramdisk_extracted
            if file ../initrd.img | grep -q "gzip"; then
                gunzip -c ../initrd.img | cpio -idm 2>/dev/null || true
            elif file ../initrd.img | grep -q "LZ4"; then
                lz4 -d ../initrd.img - | cpio -idm 2>/dev/null || true
            else
                cpio -idm < ../initrd.img 2>/dev/null || true
            fi
            cd ..
            return 0
        fi
    fi
    
    # Manual extraction as fallback
    print_warn "Trying manual extraction methods..."
    
    # Look for ramdisk offset in boot image
    local offset=$(strings "$image" | grep -abo "070701" | head -1 | cut -d: -f1)
    if [ -n "$offset" ]; then
        print_info "Found CPIO archive at offset: $offset"
        dd if="$image" bs=1 skip="$offset" of=ramdisk.cpio 2>/dev/null
        mkdir -p ramdisk_extracted
        cd ramdisk_extracted
        cpio -idm < ../ramdisk.cpio 2>/dev/null || true
        cd ..
        return 0
    fi
    
    return 1
}

# Extract the boot image
print_info "Attempting to extract boot image..."
extract_ramdisk "$BOOT_IMAGE" || {
    print_error "Failed to extract ramdisk from boot image"
    exit 1
}

# List of touchscreen modules to look for
TOUCH_MODULES=(
    "focaltech_touch.ko"
    "focaltech_ts.ko"
    "goodix_cap.ko"
    "goodix_core.ko"
    "goodix_ts.ko"
    "synaptics_tcm2.ko"
    "synaptics_tcm.ko"
    "synaptics_dsx.ko"
    "speed_touch.ko"
    "xiaomi_touch.ko"
    "nt36xxx-i2c.ko"
    "nt36xxx-spi.ko"
    "ilitek.ko"
    "himax.ko"
)

# Also look for dependency modules
DEPENDENCY_MODULES=(
    "q6_pdr_dlkm.ko"
    "q6_notifier_dlkm.ko"
    "snd_event_dlkm.ko"
    "gpr_dlkm.ko"
    "spf_core_dlkm.ko"
    "adsp_loader_dlkm.ko"
)

print_info "Searching for touchscreen and dependency modules..."

FOUND_MODULES=0

# Search for modules in common locations
search_and_copy_modules() {
    local module_list=("$@")
    
    for module in "${module_list[@]}"; do
        print_info "Looking for $module..."
        
        # Find module in extracted ramdisk
        found_files=$(find . -name "$module" 2>/dev/null || true)
        
        if [ -n "$found_files" ]; then
            for file in $found_files; do
                print_info "Found: $file"
                cp -v "$file" "$OUTPUT_DIR/"
                ((FOUND_MODULES++))
            done
        else
            print_warn "Module $module not found"
        fi
    done
}

# Search for all modules
search_and_copy_modules "${TOUCH_MODULES[@]}"
search_and_copy_modules "${DEPENDENCY_MODULES[@]}"

# Also copy any other .ko files found in vendor/lib/modules
if [ -d "ramdisk_extracted/vendor/lib/modules" ] || [ -d "vendor/lib/modules" ]; then
    print_info "Copying all kernel modules from vendor/lib/modules..."
    find . -path "*/vendor/lib/modules/*.ko" -exec cp -v {} "$OUTPUT_DIR/" \; 2>/dev/null || true
fi

cd - > /dev/null

print_info "Extraction complete!"
print_info "Found $FOUND_MODULES module(s)"

if [ $FOUND_MODULES -eq 0 ]; then
    print_warn "No modules were extracted. This could mean:"
    print_warn "  1. The modules are in the kernel image (built-in)"
    print_warn "  2. The modules are in vendor_boot.img instead of boot.img"
    print_warn "  3. The boot image format is not supported"
    print_warn ""
    print_warn "Try extracting from vendor_boot.img if available"
    exit 1
fi

# List extracted files
print_info "Extracted files:"
ls -lh "$OUTPUT_DIR"

print_info ""
print_info "Next steps:"
print_info "  1. Copy the extracted modules to your device tree:"
print_info "     mkdir -p prebuilts/<device_codename>/modules"
print_info "     cp $OUTPUT_DIR/*.ko prebuilts/<device_codename>/modules/"
print_info ""
print_info "  2. Update your device makefile (twrp_<device>.mk):"
print_info "     Add: PRODUCT_COPY_FILES += \$(call find-copy-subdir-files,*,\\"
print_info "          device/xiaomi/sm8650/prebuilts/<device>/modules,recovery/root/vendor/lib/modules)"
print_info ""
print_info "  3. Rebuild your recovery image"

exit 0
