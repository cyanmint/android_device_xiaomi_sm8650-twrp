#!/bin/bash
#
# Script to create a minimal module set for recovery to reduce image size
# Copyright (C) 2025 The TWRP Open Source Project
#
# Usage: ./create_minimal_modules.sh <device_codename> <full_modules_dir> <minimal_modules_dir>
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    print_error "Usage: $0 <device_codename> <full_modules_dir> <minimal_modules_dir>"
    echo ""
    echo "This script creates a minimal module set for recovery to avoid"
    echo "exceeding the recovery partition size limit."
    echo ""
    echo "Arguments:"
    echo "  device_codename     - Device name (e.g., ruyi, aurora)"
    echo "  full_modules_dir    - Directory with all extracted modules"
    echo "  minimal_modules_dir - Output directory for minimal modules"
    echo ""
    echo "Example:"
    echo "  $0 ruyi prebuilts/ruyi/modules prebuilts/ruyi/modules_minimal"
    exit 1
fi

DEVICE_CODENAME="$1"
FULL_MODULES_DIR="$2"
MINIMAL_MODULES_DIR="$3"

# Check if full modules directory exists
if [ ! -d "$FULL_MODULES_DIR" ]; then
    print_error "Full modules directory not found: $FULL_MODULES_DIR"
    exit 1
fi

# List of essential modules for touchscreen and basic functionality
# Based on init.recovery.qcom.rc requirements
ESSENTIAL_MODULES=(
    # Audio/ADSP dependencies (required for touchscreen on some devices)
    "q6_pdr_dlkm.ko"
    "q6_notifier_dlkm.ko"
    "snd_event_dlkm.ko"
    "gpr_dlkm.ko"
    "spf_core_dlkm.ko"
    "adsp_loader_dlkm.ko"
    
    # Touchscreen drivers
    "focaltech_touch.ko"
    "goodix_cap.ko"
    "goodix_core.ko"
    "synaptics_tcm2.ko"
    "speed_touch.ko"
    "xiaomi_touch.ko"
    
    # Additional critical modules for recovery
    "binder_gki.ko"           # Essential for Android services
    "msm_drm.ko"              # Display support
)

# Additional useful modules (can be commented out if space is limited)
USEFUL_MODULES=(
    "qcom-spmi-pmic.ko"       # Power management
    "pinctrl-spmi-gpio.ko"    # GPIO control
    "i2c-msm-geni.ko"         # I2C bus (touchscreen communication)
    "spi-msm-geni.ko"         # SPI bus (some touchscreens)
    "phy-qcom-ufs.ko"         # Storage
    "ufs_qcom.ko"             # Storage
)

print_info "Creating minimal module set for $DEVICE_CODENAME"
print_info "Source: $FULL_MODULES_DIR"
print_info "Destination: $MINIMAL_MODULES_DIR"
echo ""

# Create output directory
mkdir -p "$MINIMAL_MODULES_DIR"

COPIED_COUNT=0
MISSING_COUNT=0
TOTAL_SIZE=0

print_info "Copying essential modules..."
for module in "${ESSENTIAL_MODULES[@]}"; do
    if [ -f "$FULL_MODULES_DIR/$module" ]; then
        cp "$FULL_MODULES_DIR/$module" "$MINIMAL_MODULES_DIR/"
        SIZE=$(stat -f%z "$FULL_MODULES_DIR/$module" 2>/dev/null || stat -c%s "$FULL_MODULES_DIR/$module" 2>/dev/null)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        print_info "  ✓ Copied $module ($(numfmt --to=iec-i --suffix=B $SIZE 2>/dev/null || echo "${SIZE} bytes"))"
        ((COPIED_COUNT++))
    else
        print_warn "  ✗ Missing $module (not available in source)"
        ((MISSING_COUNT++))
    fi
done

echo ""
print_info "Copying useful modules..."
for module in "${USEFUL_MODULES[@]}"; do
    if [ -f "$FULL_MODULES_DIR/$module" ]; then
        cp "$FULL_MODULES_DIR/$module" "$MINIMAL_MODULES_DIR/"
        SIZE=$(stat -f%z "$FULL_MODULES_DIR/$module" 2>/dev/null || stat -c%s "$FULL_MODULES_DIR/$module" 2>/dev/null)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        print_info "  ✓ Copied $module ($(numfmt --to=iec-i --suffix=B $SIZE 2>/dev/null || echo "${SIZE} bytes"))"
        ((COPIED_COUNT++))
    else
        print_warn "  ✗ Skipped $module (not available)"
    fi
done

echo ""
print_info "=========================================="
print_info "Minimal Module Set Summary"
print_info "=========================================="
print_info "Modules copied: $COPIED_COUNT"
print_info "Modules missing: $MISSING_COUNT"
print_info "Total size: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE 2>/dev/null || echo "$TOTAL_SIZE bytes")"
echo ""

if [ $COPIED_COUNT -eq 0 ]; then
    print_error "No modules were copied!"
    print_warn "This likely means the required modules are not in the source directory."
    print_warn "Consider using all available modules or extracting from a different source."
    exit 1
fi

# List all copied modules
print_info "Modules in minimal set:"
ls -lh "$MINIMAL_MODULES_DIR"/*.ko 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'

echo ""
print_info "Next steps:"
print_info "  1. Update twrp_${DEVICE_CODENAME}.mk to use minimal modules:"
print_info "     Change: prebuilts/${DEVICE_CODENAME}/modules"
print_info "     To:     prebuilts/${DEVICE_CODENAME}/modules_minimal"
print_info ""
print_info "  2. Or use this command to update automatically:"
print_info "     sed -i 's|/modules,|/modules_minimal,|g' twrp_${DEVICE_CODENAME}.mk"
print_info ""
print_info "  3. Rebuild recovery and check size"

exit 0
