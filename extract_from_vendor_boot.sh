#!/bin/bash
#
# Script to extract kernel modules from vendor_boot partition (v4 format with LZ4)
# Copyright (C) 2025 The TWRP Open Source Project
#
# Usage: ./extract_from_vendor_boot.sh <vendor_boot_image> <output_dir> [device_codename]
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
    print_error "Usage: $0 <vendor_boot_image> <output_dir> [device_codename]"
    echo ""
    echo "Example: $0 vendor_boot.img extracted_modules ruyi"
    echo ""
    echo "This script extracts kernel modules from Android Boot Image v4 vendor_boot"
    echo "with LZ4 compression."
    exit 1
fi

VENDOR_BOOT="$1"
OUTPUT_DIR="$2"
DEVICE_CODENAME="$3"
TEMP_DIR=$(mktemp -d)

# Check if vendor_boot exists
if [ ! -f "$VENDOR_BOOT" ]; then
    print_error "Vendor boot image not found: $VENDOR_BOOT"
    exit 1
fi

# Check for required tools
if ! command -v lz4 &> /dev/null; then
    print_error "lz4 is not installed. Please install: apt-get install lz4"
    exit 1
fi

if ! command -v cpio &> /dev/null; then
    print_error "cpio is not installed. Please install: apt-get install cpio"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    print_error "python3 is not installed"
    exit 1
fi

print_info "Extracting modules from vendor_boot (v4 with LZ4)..."
print_info "Input: $VENDOR_BOOT"
print_info "Output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"
cd "$TEMP_DIR"

# Extract and decompress using Python
VENDOR_BOOT="$VENDOR_BOOT" OUTPUT_DIR="$OUTPUT_DIR" python3 << 'PYEOF'
import struct
import subprocess
import os
import sys

def extract_vendor_boot_v4(img_path, output_dir):
    try:
        with open(img_path, 'rb') as f:
            # Read header
            header = f.read(2128)
            magic = header[0:8]
            
            if magic != b'VNDRBOOT':
                print(f"ERROR: Not a vendor boot image (magic: {magic})")
                return False
            
            print(f"Detected VNDRBOOT image")
            
            # Extract LZ4 compressed data starting at page boundary (4096)
            f.seek(4096)
            compressed_data = f.read(80 * 1024 * 1024)  # Read 80MB
            
            with open('vendor_compressed.lz4', 'wb') as out:
                out.write(compressed_data)
            
            print("Wrote compressed data")
            
            # Decompress with lz4
            result = subprocess.run(['lz4', '-d', '-c', 'vendor_compressed.lz4'],
                                  stdout=open('vendor_ramdisk.cpio', 'wb'),
                                  stderr=subprocess.PIPE,
                                  timeout=30)
            
            if result.returncode != 0:
                print(f"ERROR: lz4 decompression failed")
                return False
            
            print("Decompressed ramdisk")
            
            # Extract CPIO
            os.makedirs('vendor_extract', exist_ok=True)
            os.chdir('vendor_extract')
            
            result = subprocess.run(['cpio', '-idm', '--quiet'],
                                  stdin=open('../vendor_ramdisk.cpio', 'rb'),
                                  stdout=subprocess.DEVNULL,
                                  stderr=subprocess.PIPE,
                                  timeout=60)
            
            print("Extracted CPIO archive")
            
            # Find and copy all .ko modules
            modules_found = 0
            if os.path.exists('lib/modules'):
                for root, dirs, files in os.walk('lib/modules'):
                    for file in files:
                        if file.endswith('.ko'):
                            src = os.path.join(root, file)
                            dst = os.path.join(output_dir, file)
                            
                            # Read and write to copy
                            with open(src, 'rb') as sf:
                                with open(dst, 'wb') as df:
                                    df.write(sf.read())
                            
                            modules_found += 1
                            print(f"Copied: {file}")
            
            print(f"\nTotal modules extracted: {modules_found}")
            return modules_found > 0
            
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        return False

# Get arguments from environment
img_path = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('VENDOR_BOOT')
output_dir = sys.argv[2] if len(sys.argv) > 2 else os.environ.get('OUTPUT_DIR')

if not extract_vendor_boot_v4(img_path, output_dir):
    sys.exit(1)
PYEOF

PYTHON_EXIT=$?

if [ $PYTHON_EXIT -ne 0 ]; then
    print_error "Extraction failed"
    cd /
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Cleanup
cd /
rm -rf "$TEMP_DIR"

MODULE_COUNT=$(find "$OUTPUT_DIR" -name "*.ko" 2>/dev/null | wc -l)

print_info ""
print_info "Extraction complete!"
print_info "Extracted $MODULE_COUNT kernel module(s) to: $OUTPUT_DIR"
print_info ""

if [ $MODULE_COUNT -eq 0 ]; then
    print_warn "No modules were extracted"
    exit 1
fi

# List extracted modules
print_info "Extracted modules:"
find "$OUTPUT_DIR" -name "*.ko" -exec basename {} \; | sort

# If device codename is provided, offer to add to device tree
if [ -n "$DEVICE_CODENAME" ]; then
    print_info ""
    print_info "Next steps for device '$DEVICE_CODENAME':"
    print_info "  1. Review extracted modules above"
    print_info "  2. Run: ./add_modules_to_recovery.sh $DEVICE_CODENAME $OUTPUT_DIR"
    print_info "  3. Run: ./verify_setup.sh $DEVICE_CODENAME"
    print_info "  4. Rebuild recovery"
fi

exit 0
