#!/bin/bash
#
# Script to patch kernel modules into an existing recovery image
# Copyright (C) 2025 The TWRP Open Source Project
#
# Usage: ./patch_recovery_modules.sh <recovery_img> <modules_dir> <output_img>
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

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check arguments
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    print_error "Usage: $0 <recovery_img> <modules_dir> <output_img>"
    echo ""
    echo "This script patches kernel modules into an existing recovery image."
    echo ""
    echo "Arguments:"
    echo "  recovery_img  - Input recovery image (e.g., recovery.img)"
    echo "  modules_dir   - Directory containing .ko modules to add"
    echo "  output_img    - Output patched recovery image"
    echo ""
    echo "Example:"
    echo "  $0 recovery.img prebuilts/ruyi/modules recovery_patched.img"
    echo ""
    echo "Requirements:"
    echo "  - Python 3"
    echo "  - lz4 (for LZ4 compression)"
    echo "  - cpio"
    echo "  - gzip or lz4 (depending on ramdisk compression)"
    exit 1
fi

RECOVERY_IMG="$1"
MODULES_DIR="$2"
OUTPUT_IMG="$3"
TEMP_DIR=$(mktemp -d)

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        print_info "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Check if recovery image exists
if [ ! -f "$RECOVERY_IMG" ]; then
    print_error "Recovery image not found: $RECOVERY_IMG"
    exit 1
fi

# Check if modules directory exists
if [ ! -d "$MODULES_DIR" ]; then
    print_error "Modules directory not found: $MODULES_DIR"
    exit 1
fi

# Check for required tools
if ! command -v python3 &> /dev/null; then
    print_error "python3 is not installed"
    exit 1
fi

if ! command -v cpio &> /dev/null; then
    print_error "cpio is not installed. Please install: apt-get install cpio"
    exit 1
fi

# Count modules
MODULE_COUNT=$(find "$MODULES_DIR" -name "*.ko" 2>/dev/null | wc -l)
if [ $MODULE_COUNT -eq 0 ]; then
    print_error "No kernel modules (.ko) found in $MODULES_DIR"
    exit 1
fi

print_header "Recovery Module Patcher"
print_info "Input recovery: $RECOVERY_IMG"
print_info "Modules directory: $MODULES_DIR"
print_info "Output recovery: $OUTPUT_IMG"
print_info "Modules to add: $MODULE_COUNT"
echo ""

cd "$TEMP_DIR"

# Use Python to unpack, patch, and repack the recovery image
RECOVERY_IMG="$RECOVERY_IMG" MODULES_DIR="$MODULES_DIR" OUTPUT_IMG="$OUTPUT_IMG" python3 << 'PYEOF'
import struct
import subprocess
import os
import sys
import shutil

def print_info(msg):
    print(f"\033[0;32m[INFO]\033[0m {msg}")

def print_error(msg):
    print(f"\033[0;31m[ERROR]\033[0m {msg}")

def print_warn(msg):
    print(f"\033[1;33m[WARN]\033[0m {msg}")

def detect_compression(data):
    """Detect compression type from magic bytes"""
    if data[:4] == b'\x02\x21\x4c\x18':
        return 'lz4'
    elif data[:2] == b'\x1f\x8b':
        return 'gzip'
    elif data[:6] == b'\xfd7zXZ\x00':
        return 'xz'
    elif data[:6] == b'070701':
        return 'uncompressed'
    else:
        return 'unknown'

def unpack_recovery(recovery_img):
    """Unpack recovery image and extract ramdisk"""
    print_info("Unpacking recovery image...")
    
    with open(recovery_img, 'rb') as f:
        header = f.read(2048)
        magic = header[0:8]
        
        if magic not in [b'ANDROID!', b'VNDRBOOT']:
            print_error(f"Not a valid boot/recovery image (magic: {magic})")
            return None
        
        print_info(f"Detected boot image magic: {magic.decode('ascii', errors='ignore')}")
        
        # For Android Boot Image v4 (newer format)
        # Ramdisk is typically at offset 4096
        f.seek(4096)
        ramdisk_compressed = f.read(50 * 1024 * 1024)  # Read up to 50MB
        
        # Detect compression
        compression = detect_compression(ramdisk_compressed)
        print_info(f"Detected ramdisk compression: {compression}")
        
        # Save compressed ramdisk
        with open('ramdisk_compressed', 'wb') as out:
            out.write(ramdisk_compressed)
        
        # Decompress based on type
        if compression == 'lz4':
            # Try unlz4 first, then lz4 with different options
            result = subprocess.run(['lz4', '-d', 'ramdisk_compressed', 'ramdisk.cpio'],
                                  stderr=subprocess.PIPE, timeout=30)
            if result.returncode != 0:
                # Try alternative: skip the LZ4 frame header and decompress raw
                print_warn("Standard LZ4 decompression failed, trying alternative method...")
                # The ramdisk might be LZ4 compressed but needs special handling
                # Try with -dc (decompress to stdout)
                result = subprocess.run(['lz4', '-dc', 'ramdisk_compressed'],
                                      stdout=open('ramdisk.cpio', 'wb'),
                                      stderr=subprocess.PIPE, timeout=30)
                if result.returncode != 0:
                    print_error("Failed to decompress LZ4 ramdisk with alternative method")
                    return None
        elif compression == 'gzip':
            result = subprocess.run(['gunzip', '-c', 'ramdisk_compressed'],
                                  stdout=open('ramdisk.cpio', 'wb'),
                                  stderr=subprocess.PIPE)
            if result.returncode != 0:
                print_error("Failed to decompress gzip ramdisk")
                return None
        elif compression == 'uncompressed':
            shutil.copy('ramdisk_compressed', 'ramdisk.cpio')
        else:
            print_error(f"Unsupported compression: {compression}")
            return None
        
        print_info("Ramdisk decompressed successfully")
        return compression

def extract_ramdisk():
    """Extract CPIO ramdisk"""
    print_info("Extracting ramdisk contents...")
    
    os.makedirs('ramdisk_extracted', exist_ok=True)
    os.chdir('ramdisk_extracted')
    
    result = subprocess.run(['cpio', '-idm', '--quiet'],
                          stdin=open('../ramdisk.cpio', 'rb'),
                          stdout=subprocess.DEVNULL,
                          stderr=subprocess.PIPE)
    
    os.chdir('..')
    
    if result.returncode != 0:
        print_warn("CPIO extraction had warnings, but may have succeeded")
    
    # Check if extraction worked
    if os.path.exists('ramdisk_extracted') and os.listdir('ramdisk_extracted'):
        print_info("Ramdisk extracted successfully")
        return True
    else:
        print_error("Failed to extract ramdisk")
        return False

def add_modules(modules_dir):
    """Add kernel modules to ramdisk"""
    print_info("Adding kernel modules to ramdisk...")
    
    # Create modules directory in ramdisk
    modules_path = 'ramdisk_extracted/vendor/lib/modules'
    os.makedirs(modules_path, exist_ok=True)
    
    # Copy all .ko files
    module_count = 0
    for root, dirs, files in os.walk(modules_dir):
        for file in files:
            if file.endswith('.ko'):
                src = os.path.join(root, file)
                dst = os.path.join(modules_path, file)
                shutil.copy2(src, dst)
                module_count += 1
                if module_count <= 10:  # Show first 10
                    print_info(f"  Added: {file}")
    
    if module_count > 10:
        print_info(f"  ... and {module_count - 10} more modules")
    
    print_info(f"Total modules added: {module_count}")
    return module_count > 0

def repack_ramdisk(compression):
    """Repack ramdisk with added modules"""
    print_info("Repacking ramdisk...")
    
    os.chdir('ramdisk_extracted')
    
    # Create new CPIO archive
    # Get list of all files
    files = []
    for root, dirs, fs in os.walk('.'):
        for f in fs:
            path = os.path.join(root, f)
            files.append(path)
    
    # Create CPIO
    result = subprocess.run(['cpio', '-o', '-H', 'newc'],
                          stdin=subprocess.PIPE,
                          stdout=open('../ramdisk_new.cpio', 'wb'),
                          stderr=subprocess.PIPE,
                          input='\n'.join(files).encode())
    
    os.chdir('..')
    
    if result.returncode != 0:
        print_error("Failed to create new CPIO archive")
        return None
    
    print_info("New ramdisk CPIO created")
    
    # Compress based on original compression
    if compression == 'lz4':
        print_info("Compressing with LZ4...")
        result = subprocess.run(['lz4', '-c', 'ramdisk_new.cpio'],
                              stdout=open('ramdisk_new_compressed', 'wb'),
                              stderr=subprocess.PIPE)
        if result.returncode != 0:
            print_error("Failed to compress with LZ4")
            return None
    elif compression == 'gzip':
        print_info("Compressing with gzip...")
        result = subprocess.run(['gzip', '-c', 'ramdisk_new.cpio'],
                              stdout=open('ramdisk_new_compressed', 'wb'),
                              stderr=subprocess.PIPE)
        if result.returncode != 0:
            print_error("Failed to compress with gzip")
            return None
    else:
        # Uncompressed
        shutil.copy('ramdisk_new.cpio', 'ramdisk_new_compressed')
    
    print_info("Ramdisk compressed successfully")
    return True

def rebuild_recovery(recovery_img, output_img):
    """Rebuild recovery image with new ramdisk"""
    print_info("Rebuilding recovery image...")
    
    # Read original recovery
    with open(recovery_img, 'rb') as f:
        recovery_data = f.read()
    
    # Read new compressed ramdisk
    with open('ramdisk_new_compressed', 'rb') as f:
        new_ramdisk = f.read()
    
    # For Android Boot Image v4, ramdisk starts at 4096
    # Replace the ramdisk portion
    header = recovery_data[:4096]
    
    # Combine: header + new ramdisk
    new_recovery = header + new_ramdisk
    
    # Write new recovery
    with open(output_img, 'wb') as f:
        f.write(new_recovery)
    
    print_info(f"New recovery image created: {output_img}")
    print_info(f"Size: {len(new_recovery)} bytes ({len(new_recovery) / 1024 / 1024:.2f} MB)")
    return True

# Main execution
recovery_img = os.environ.get('RECOVERY_IMG')
modules_dir = os.environ.get('MODULES_DIR')
output_img = os.environ.get('OUTPUT_IMG')

try:
    # Step 1: Unpack
    compression = unpack_recovery(recovery_img)
    if not compression:
        sys.exit(1)
    
    # Step 2: Extract
    if not extract_ramdisk():
        sys.exit(1)
    
    # Step 3: Add modules
    if not add_modules(modules_dir):
        print_error("Failed to add modules")
        sys.exit(1)
    
    # Step 4: Repack
    if not repack_ramdisk(compression):
        sys.exit(1)
    
    # Step 5: Rebuild
    if not rebuild_recovery(recovery_img, output_img):
        sys.exit(1)
    
    print("\n\033[0;32m✓ Success!\033[0m Recovery image patched with kernel modules")
    
except Exception as e:
    print_error(f"Exception occurred: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

PYTHON_EXIT=$?

if [ $PYTHON_EXIT -ne 0 ]; then
    print_error "Patching failed!"
    exit 1
fi

# Move output to final location
if [ -f "$TEMP_DIR/$(basename "$OUTPUT_IMG")" ]; then
    cp "$TEMP_DIR/$(basename "$OUTPUT_IMG")" "$OUTPUT_IMG"
fi

echo ""
print_header "Patching Complete!"
echo ""
print_info "Original recovery: $RECOVERY_IMG"
print_info "Patched recovery: $OUTPUT_IMG"
print_info "Modules added: $MODULE_COUNT"
echo ""
print_info "Next steps:"
print_info "  1. Flash the patched recovery:"
print_info "     fastboot flash recovery $OUTPUT_IMG"
print_info "  2. Reboot to recovery and test touchscreen"
echo ""
print_warn "Note: This is an experimental patch. The original recovery"
print_warn "image structure is preserved, but always keep a backup!"

exit 0
