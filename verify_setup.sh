#!/bin/bash
#
# Script to verify touchscreen module setup
# Copyright (C) 2025 The TWRP Open Source Project
#
# Usage: ./verify_setup.sh <device_codename>
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <device_codename>"
    echo ""
    echo "Available devices:"
    ls -1 prebuilts/ 2>/dev/null | grep -v ".git" || echo "  (no devices found)"
    exit 1
fi

DEVICE_CODENAME="$1"
DEVICE_MAKEFILE="twrp_${DEVICE_CODENAME}.mk"
MODULES_DIR="prebuilts/$DEVICE_CODENAME/modules"
INIT_RC="recovery/root/init.recovery.qcom.rc"

ISSUES=0
WARNINGS=0

echo "========================================"
echo "Touchscreen Setup Verification"
echo "Device: $DEVICE_CODENAME"
echo "========================================"
echo ""

# Check 1: Device exists
echo "1. Checking device existence..."
if [ -d "prebuilts/$DEVICE_CODENAME" ]; then
    print_pass "Device directory exists: prebuilts/$DEVICE_CODENAME"
else
    print_fail "Device directory not found: prebuilts/$DEVICE_CODENAME"
    ((ISSUES++))
fi
echo ""

# Check 2: Modules directory
echo "2. Checking modules directory..."
if [ -d "$MODULES_DIR" ]; then
    print_pass "Modules directory exists: $MODULES_DIR"
    
    # Count modules
    MODULE_COUNT=$(find "$MODULES_DIR" -name "*.ko" 2>/dev/null | wc -l)
    if [ "$MODULE_COUNT" -gt 0 ]; then
        print_pass "Found $MODULE_COUNT kernel module(s)"
        echo "   Modules:"
        find "$MODULES_DIR" -name "*.ko" -exec basename {} \; | sed 's/^/     - /'
    else
        print_fail "No kernel modules (.ko) found in $MODULES_DIR"
        ((ISSUES++))
    fi
else
    print_fail "Modules directory not found: $MODULES_DIR"
    print_info "Run: ./extract_touch_modules.sh boot.img && ./add_modules_to_recovery.sh $DEVICE_CODENAME extracted_modules"
    ((ISSUES++))
fi
echo ""

# Check 3: Device makefile
echo "3. Checking device makefile..."
if [ -f "$DEVICE_MAKEFILE" ]; then
    print_pass "Device makefile exists: $DEVICE_MAKEFILE"
    
    # Check if modules are referenced
    if grep -q "prebuilts/$DEVICE_CODENAME/modules" "$DEVICE_MAKEFILE"; then
        print_pass "Modules referenced in makefile"
        
        # Show the line
        echo "   Configuration:"
        grep -A1 "prebuilts/$DEVICE_CODENAME/modules" "$DEVICE_MAKEFILE" | sed 's/^/     /'
    else
        print_fail "Modules not referenced in makefile"
        print_info "Run: ./add_modules_to_recovery.sh $DEVICE_CODENAME <modules_directory>"
        ((ISSUES++))
    fi
else
    print_fail "Device makefile not found: $DEVICE_MAKEFILE"
    ((ISSUES++))
fi
echo ""

# Check 4: Init RC file
echo "4. Checking init recovery script..."
if [ -f "$INIT_RC" ]; then
    print_pass "Init script exists: $INIT_RC"
    
    # Check for touch module loading
    if grep -q "insmod.*touch" "$INIT_RC"; then
        print_pass "Touch module loading configured"
        
        # List touch modules
        echo "   Configured modules:"
        grep "insmod.*touch" "$INIT_RC" | sed 's/.*\//     - /'
    else
        print_warn "No touch module loading found in init script"
        print_info "This is usually pre-configured, but verify modules are loaded"
        ((WARNINGS++))
    fi
else
    print_warn "Init script not found: $INIT_RC"
    print_info "This might be normal for some configurations"
    ((WARNINGS++))
fi
echo ""

# Check 5: Common touch modules
echo "5. Checking for common touchscreen modules..."
EXPECTED_MODULES=(
    "focaltech_touch.ko"
    "goodix_core.ko"
    "synaptics_tcm2.ko"
    "xiaomi_touch.ko"
)

FOUND_COUNT=0
for module in "${EXPECTED_MODULES[@]}"; do
    if [ -f "$MODULES_DIR/$module" ]; then
        print_pass "$module found"
        ((FOUND_COUNT++))
    fi
done

if [ $FOUND_COUNT -eq 0 ]; then
    print_warn "No common touchscreen modules found"
    print_info "This might be normal if your device uses different modules"
    ((WARNINGS++))
fi
echo ""

# Check 6: Dependency modules
echo "6. Checking for dependency modules..."
DEPENDENCY_MODULES=(
    "q6_pdr_dlkm.ko"
    "adsp_loader_dlkm.ko"
)

DEP_FOUND=0
for module in "${DEPENDENCY_MODULES[@]}"; do
    if [ -f "$MODULES_DIR/$module" ]; then
        print_pass "$module found"
        ((DEP_FOUND++))
    fi
done

if [ $DEP_FOUND -eq 0 ] && [ -d "$MODULES_DIR" ]; then
    print_warn "No dependency modules found"
    print_info "Touchscreen may not work without these dependencies"
    ((WARNINGS++))
fi
echo ""

# Summary
echo "========================================"
echo "Verification Summary"
echo "========================================"

if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Your setup looks good. Next steps:"
    echo "  1. Commit your changes: git add . && git commit -m 'Add touchscreen modules'"
    echo "  2. Rebuild recovery: lunch twrp_$DEVICE_CODENAME-eng && mka recoveryimage"
    echo "  3. Flash and test: fastboot flash recovery recovery.img"
elif [ $ISSUES -eq 0 ]; then
    echo -e "${YELLOW}⚠ Setup complete with $WARNINGS warning(s)${NC}"
    echo ""
    echo "You can proceed with building, but review warnings above."
else
    echo -e "${RED}✗ Found $ISSUES issue(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the issues above before building recovery."
    exit 1
fi

exit 0
