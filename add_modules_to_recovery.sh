#!/bin/bash
#
# Script to add extracted kernel modules to device tree for recovery
# Copyright (C) 2025 The TWRP Open Source Project
#
# Usage: ./add_modules_to_recovery.sh <device_codename> <modules_directory>
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    print_error "Usage: $0 <device_codename> <modules_directory>"
    echo ""
    echo "Example: $0 aurora extracted_modules"
    echo ""
    echo "Available devices:"
    ls -1 prebuilts/ 2>/dev/null | grep -v ".git" || echo "  (no devices found)"
    exit 1
fi

DEVICE_CODENAME="$1"
MODULES_DIR="$2"
DEVICE_PREBUILTS="prebuilts/$DEVICE_CODENAME"
DEVICE_MODULES_DIR="$DEVICE_PREBUILTS/modules"
DEVICE_MAKEFILE="twrp_${DEVICE_CODENAME}.mk"

# Check if modules directory exists
if [ ! -d "$MODULES_DIR" ]; then
    print_error "Modules directory not found: $MODULES_DIR"
    exit 1
fi

# Check if there are any .ko files
MODULE_COUNT=$(find "$MODULES_DIR" -name "*.ko" | wc -l)
if [ "$MODULE_COUNT" -eq 0 ]; then
    print_error "No kernel modules (.ko files) found in $MODULES_DIR"
    exit 1
fi

print_info "Found $MODULE_COUNT kernel module(s)"

# Create device modules directory
print_info "Creating modules directory: $DEVICE_MODULES_DIR"
mkdir -p "$DEVICE_MODULES_DIR"

# Copy modules
print_info "Copying modules to device tree..."
cp -v "$MODULES_DIR"/*.ko "$DEVICE_MODULES_DIR/"

# Check if device makefile exists
if [ ! -f "$DEVICE_MAKEFILE" ]; then
    print_error "Device makefile not found: $DEVICE_MAKEFILE"
    print_error "Available makefiles:"
    ls -1 twrp_*.mk 2>/dev/null || echo "  (none found)"
    exit 1
fi

# Extract DEVICE_PATH from makefile (more flexible than hardcoding)
DEVICE_PATH=$(grep -m1 "^DEVICE_PATH :=" "$DEVICE_MAKEFILE" 2>/dev/null | sed 's/DEVICE_PATH := //' | tr -d ' ')
if [ -z "$DEVICE_PATH" ]; then
    # Fallback: try to detect from directory structure
    DEVICE_PATH=$(pwd | sed 's|.*/\(device/[^/]*/[^/]*\).*|\1|')
    if [[ ! "$DEVICE_PATH" =~ ^device/ ]]; then
        # If still not detected, use a generic path
        print_warn "Could not auto-detect DEVICE_PATH, using generic path"
        DEVICE_PATH="device/vendor/codename"
    fi
fi
print_info "Detected DEVICE_PATH: $DEVICE_PATH"

# Check if PRODUCT_COPY_FILES for modules already exists
if grep -q "prebuilts/$DEVICE_CODENAME/modules" "$DEVICE_MAKEFILE"; then
    print_warn "Module copy directive already exists in $DEVICE_MAKEFILE"
    print_info "Modules have been updated in $DEVICE_MODULES_DIR"
else
    print_info "Adding module copy directive to $DEVICE_MAKEFILE"
    
    # Find the line with firmware copy, add modules copy after it
    if grep -q "prebuilts/$DEVICE_CODENAME/firmware" "$DEVICE_MAKEFILE"; then
        # Add after firmware line
        sed -i "/prebuilts\/$DEVICE_CODENAME\/firmware/a # dependencies (copy kernel modules for touchscreen)\nPRODUCT_COPY_FILES += \$(call find-copy-subdir-files,*,$DEVICE_PATH/prebuilts/$DEVICE_CODENAME/modules,recovery/root/vendor/lib/modules)" "$DEVICE_MAKEFILE"
        print_info "Added module copy directive after firmware line"
    else
        # Add after dependencies comment or device.mk inherit
        if grep -q "# dependencies" "$DEVICE_MAKEFILE"; then
            sed -i "/# dependencies/a # dependencies (copy kernel modules for touchscreen)\nPRODUCT_COPY_FILES += \$(call find-copy-subdir-files,*,$DEVICE_PATH/prebuilts/$DEVICE_CODENAME/modules,recovery/root/vendor/lib/modules)" "$DEVICE_MAKEFILE"
        else
            sed -i "/inherit-product.*device.mk/a \n# dependencies (copy kernel modules for touchscreen)\nPRODUCT_COPY_FILES += \$(call find-copy-subdir-files,*,$DEVICE_PATH/prebuilts/$DEVICE_CODENAME/modules,recovery/root/vendor/lib/modules)" "$DEVICE_MAKEFILE"
        fi
        print_info "Added module copy directive to $DEVICE_MAKEFILE"
    fi
fi

print_info ""
print_info "Success! Modules have been added to the device tree."
print_info ""
print_info "Summary:"
print_info "  - Copied $MODULE_COUNT module(s) to: $DEVICE_MODULES_DIR"
print_info "  - Updated makefile: $DEVICE_MAKEFILE"
print_info ""
print_info "Modules copied:"
ls -1 "$DEVICE_MODULES_DIR"/*.ko | xargs -n1 basename

print_info ""
print_info "Next steps:"
print_info "  1. Review the changes to $DEVICE_MAKEFILE"
print_info "  2. Rebuild your recovery image"
print_info "  3. Test touchscreen functionality in recovery"
print_info ""
print_info "Build command example:"
print_info "  lunch twrp_${DEVICE_CODENAME}-eng"
print_info "  mka recoveryimage"

exit 0
