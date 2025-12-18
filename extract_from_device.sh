#!/bin/bash
#
# Script to extract touchscreen kernel modules from a running Android device via ADB
# Copyright (C) 2025 The TWRP Open Source Project
#
# Usage: ./extract_from_device.sh <device_codename>
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

# Check if device codename is provided
if [ -z "$1" ]; then
    print_error "Usage: $0 <device_codename>"
    echo ""
    echo "This script extracts kernel modules from a running Android device"
    echo "connected via ADB and adds them to the device tree."
    echo ""
    echo "Requirements:"
    echo "  - Device must be connected via ADB"
    echo "  - ADB root access (adb root)"
    echo ""
    echo "Example: $0 ruyi"
    exit 1
fi

DEVICE_CODENAME="$1"
OUTPUT_DIR="prebuilts/$DEVICE_CODENAME/modules"

# Check if ADB is available
if ! command -v adb &> /dev/null; then
    print_error "ADB is not installed or not in PATH"
    exit 1
fi

# Check if device is connected
print_info "Checking ADB connection..."
if ! adb devices | grep -q "device$"; then
    print_error "No Android device connected via ADB"
    print_info "Please connect your device and enable USB debugging"
    exit 1
fi

print_info "Device connected!"

# Try to get root access
print_info "Attempting to get root access..."
adb root 2>&1 | grep -v "already running as root" || true
sleep 2

# Check if we have root
if ! adb shell "su -c 'id'" 2>/dev/null | grep -q "uid=0"; then
    print_warn "Root access not available via 'su' command"
    print_warn "Trying without root (may fail if /vendor is not readable)..."
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

print_info "Extracting kernel modules from device..."
print_info "Output directory: $OUTPUT_DIR"
echo ""

# List of modules to extract
MODULES=(
    "q6_pdr_dlkm.ko"
    "q6_notifier_dlkm.ko"
    "snd_event_dlkm.ko"
    "gpr_dlkm.ko"
    "spf_core_dlkm.ko"
    "adsp_loader_dlkm.ko"
    "focaltech_touch.ko"
    "goodix_cap.ko"
    "goodix_core.ko"
    "synaptics_tcm2.ko"
    "speed_touch.ko"
    "xiaomi_touch.ko"
)

FOUND_COUNT=0
FAILED_COUNT=0

for module in "${MODULES[@]}"; do
    print_info "Extracting $module..."
    
    if adb pull "/vendor/lib/modules/$module" "$OUTPUT_DIR/$module" 2>&1 | grep -q "bytes in"; then
        print_info "✓ Successfully extracted $module"
        ((FOUND_COUNT++))
    else
        print_warn "✗ Could not extract $module (may not exist on device)"
        ((FAILED_COUNT++))
    fi
done

echo ""
print_info "Extraction complete!"
print_info "Successfully extracted: $FOUND_COUNT module(s)"

if [ $FAILED_COUNT -gt 0 ]; then
    print_warn "Failed to extract: $FAILED_COUNT module(s)"
fi

if [ $FOUND_COUNT -eq 0 ]; then
    print_error "No modules were extracted!"
    print_info "Possible reasons:"
    print_info "  1. Modules are not in /vendor/lib/modules/"
    print_info "  2. Device doesn't have these specific modules"
    print_info "  3. Need root access to read /vendor partition"
    echo ""
    print_info "Try checking manually:"
    print_info "  adb shell ls -la /vendor/lib/modules/"
    exit 1
fi

# List extracted modules
echo ""
print_info "Extracted modules:"
ls -lh "$OUTPUT_DIR"/*.ko 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'

echo ""
print_info "Next steps:"
print_info "  1. Update device makefile: ./add_modules_to_recovery.sh $DEVICE_CODENAME $OUTPUT_DIR"
print_info "  2. Verify setup: ./verify_setup.sh $DEVICE_CODENAME"
print_info "  3. Commit changes: git add prebuilts/$DEVICE_CODENAME/modules && git commit"
print_info "  4. Rebuild recovery"

exit 0
