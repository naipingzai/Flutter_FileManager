#!/bin/bash
# ============================================================
# Flutter File Manager - Linux Build Script
# ============================================================
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
BUNDLE_DIR="$BUILD_DIR/linux/x64/release/bundle"

echo "============================================"
echo "  Flutter File Manager - Linux Build"
echo "============================================"
echo ""

# Step 1: Check dependencies
echo "[1/5] Checking dependencies..."
command -v flutter >/dev/null 2>&1 || { echo "ERROR: flutter not found"; exit 1; }
command -v cmake >/dev/null 2>&1 || { echo "ERROR: cmake not found"; exit 1; }
command -v g++ >/dev/null 2>&1 || { echo "ERROR: g++ not found"; exit 1; }
dpkg -l libssl-dev >/dev/null 2>&1 || { echo "ERROR: libssl-dev not installed. Run: sudo apt install libssl-dev"; exit 1; }
dpkg -l zlib1g-dev >/dev/null 2>&1 || { echo "ERROR: zlib1g-dev not installed. Run: sudo apt install zlib1g-dev"; exit 1; }
echo "  All dependencies OK"

# Step 2: Get dependencies
echo "[2/5] Getting Flutter dependencies..."
cd "$PROJECT_DIR"
flutter pub get 2>&1 | tail -3

# Step 3: Clean previous build
echo "[3/5] Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/native_assets/linux"

# Step 4: Build
echo "[4/5] Building Linux release..."
flutter build linux --release 2>&1

# Step 5: Verify
echo "[5/5] Verifying build..."
if [ -f "$BUNDLE_DIR/flutter_file_manager" ]; then
    EXEC_SIZE=$(stat -c%s "$BUNDLE_DIR/flutter_file_manager")
    LIB_SIZE=$(stat -c%s "$BUNDLE_DIR/lib/libfile_ops.so" 2>/dev/null || echo "0")
    echo ""
    echo "============================================"
    echo "  BUILD SUCCESSFUL"
    echo "============================================"
    echo "  Binary: $BUNDLE_DIR/flutter_file_manager ($EXEC_SIZE bytes)"
    echo "  Native: $BUNDLE_DIR/lib/libfile_ops.so ($LIB_SIZE bytes)"
    echo ""
    echo "  Run: $BUNDLE_DIR/flutter_file_manager"
    echo "============================================"
else
    echo "ERROR: Build failed - binary not found"
    exit 1
fi
