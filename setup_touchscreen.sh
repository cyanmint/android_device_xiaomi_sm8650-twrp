#!/bin/bash
#
# All-in-one script: Extract touchscreen modules and add to device tree
# Copyright (C) 2025 The TWRP Open Source Project
#
# Usage: ./setup_touchscreen.sh <boot_image> <device_codename>
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    print_error "Usage: $0 <boot_image> <device_codename>"
    echo ""
    echo "This script will:"
    echo "  1. Extract touchscreen modules from boot image"
    echo "  2. Add them to your device tree"
    echo "  3. Update device makefile"
    echo ""
    echo "Example: $0 boot.img aurora"
    echo "         $0 vendor_boot.img peridot"
    echo ""
    echo "Available devices:"
    ls -1 prebuilts/ 2>/dev/null | grep -v ".git" || echo "  (no devices found)"
    exit 1
fi

BOOT_IMAGE="$1"
DEVICE_CODENAME="$2"
TEMP_MODULES="extracted_modules_temp_$$"

# Verify boot image exists
if [ ! -f "$BOOT_IMAGE" ]; then
    print_error "Boot image not found: $BOOT_IMAGE"
    exit 1
fi

# Verify device exists
if [ ! -d "prebuilts/$DEVICE_CODENAME" ]; then
    print_error "Device '$DEVICE_CODENAME' not found in prebuilts/"
    print_info "Available devices:"
    ls -1 prebuilts/ 2>/dev/null | grep -v ".git"
    exit 1
fi

print_header "Touchscreen Module Setup"
print_info "Boot image: $BOOT_IMAGE"
print_info "Device: $DEVICE_CODENAME"
echo ""

# Step 1: Extract modules
print_header "Step 1: Extracting Modules"
if ! ./extract_touch_modules.sh "$BOOT_IMAGE" "$TEMP_MODULES"; then
    print_error "Failed to extract modules from boot image"
    exit 1
fi

echo ""

# Check if any modules were extracted
if [ ! -d "$TEMP_MODULES" ] || [ -z "$(ls -A $TEMP_MODULES/*.ko 2>/dev/null)" ]; then
    print_error "No kernel modules were extracted"
    print_warn "Possible solutions:"
    print_warn "  1. Try with vendor_boot.img instead"
    print_warn "  2. Try with init_boot.img (Android 13+)"
    print_warn "  3. Check if drivers are built into kernel"
    rm -rf "$TEMP_MODULES"
    exit 1
fi

# Step 2: Add to device tree
print_header "Step 2: Adding to Device Tree"
if ! ./add_modules_to_recovery.sh "$DEVICE_CODENAME" "$TEMP_MODULES"; then
    print_error "Failed to add modules to device tree"
    rm -rf "$TEMP_MODULES"
    exit 1
fi

# Cleanup temp directory
rm -rf "$TEMP_MODULES"

echo ""
print_header "Setup Complete!"
echo ""
print_info "✓ Modules extracted from boot image"
print_info "✓ Modules copied to prebuilts/$DEVICE_CODENAME/modules/"
print_info "✓ Makefile updated: twrp_$DEVICE_CODENAME.mk"
echo ""
print_info "Files modified:"
echo "  - twrp_$DEVICE_CODENAME.mk (device makefile)"
echo "  - prebuilts/$DEVICE_CODENAME/modules/*.ko (kernel modules)"
echo ""
print_warn "Next steps:"
print_warn "  1. Review changes with: git diff"
print_warn "  2. Commit changes: git add . && git commit -m 'Add touchscreen modules'"
print_warn "  3. Rebuild recovery image"
print_warn "  4. Test touchscreen in recovery"
echo ""
print_info "Build commands:"
echo "  cd \$TWRP_SOURCE"
echo "  . build/envsetup.sh"
echo "  lunch twrp_$DEVICE_CODENAME-eng"
echo "  mka recoveryimage"
echo ""

exit 0
