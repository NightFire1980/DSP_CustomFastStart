#!/usr/bin/env bash
set -euo pipefail

# Thunderstore package builder (bash port of build-thunderstore.ps1)

Author="stat0s2p"
Configuration="Release"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_FILE="$SCRIPT_DIR/DSP_CustomFastStart/DSP_CustomFastStart.csproj"
THUNDERSTORE_DIR="$SCRIPT_DIR/thunderstore"
MANIFEST_PATH="$THUNDERSTORE_DIR/manifest.json"
README_PATH="$THUNDERSTORE_DIR/README.md"
CHANGELOG_PATH="$THUNDERSTORE_DIR/CHANGELOG.md"
ICON_PATH="$THUNDERSTORE_DIR/icon.png"

[ -f "$MANIFEST_PATH" ] || { echo "Missing manifest: $MANIFEST_PATH" >&2; exit 1; }
[ -f "$README_PATH"  ] || { echo "Missing README: $README_PATH" >&2; exit 1; }
[ -f "$ICON_PATH"    ] || { echo "Missing icon: $ICON_PATH" >&2; exit 1; }

packageName="$(jq -r '.name' "$MANIFEST_PATH")"
version="$(jq -r '.version_number' "$MANIFEST_PATH")"
[ -n "$packageName" ] || { echo "manifest.name is empty." >&2; exit 1; }
[ -n "$version" ]     || { echo "manifest.version_number is empty." >&2; exit 1; }

echo "Building plugin ($Configuration)..."
dotnet build "$PROJECT_FILE" -c "$Configuration" -nologo

DLL_PATH="$SCRIPT_DIR/DSP_CustomFastStart/bin/$Configuration/net472/DSP_CustomFastStart.dll"
[ -f "$DLL_PATH" ] || { echo "Build output missing: $DLL_PATH" >&2; exit 1; }

# Validate icon size: Thunderstore requires 256x256 png
python3 - "$ICON_PATH" <<'PY'
import sys
from PIL import Image
path = sys.argv[1]
with Image.open(path) as img:
    if img.width != 256 or img.height != 256:
        sys.stderr.write(f"icon.png must be 256x256, got {img.width}x{img.height}.\n")
        sys.exit(1)
PY

BUILD_DIR="$THUNDERSTORE_DIR/build"
DIST_DIR="$THUNDERSTORE_DIR/dist"
STAGE_DIR="$BUILD_DIR/package"

rm -rf "$STAGE_DIR"
mkdir -p "$DIST_DIR" "$STAGE_DIR"

cp "$DLL_PATH"        "$STAGE_DIR/DSP_CustomFastStart.dll"
cp "$MANIFEST_PATH"   "$STAGE_DIR/manifest.json"
cp "$README_PATH"     "$STAGE_DIR/README.md"
[ -f "$CHANGELOG_PATH" ] && cp "$CHANGELOG_PATH" "$STAGE_DIR/CHANGELOG.md"
cp "$ICON_PATH"       "$STAGE_DIR/icon.png"

ZIP_NAME="$Author-$packageName-$version.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"

# Build the zip with Python's zipfile (no system 'zip' available)
python3 - "$STAGE_DIR" "$ZIP_PATH" <<'PY'
import os, sys, zipfile
stage, zip_path = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    for name in sorted(os.listdir(stage)):
        zf.write(os.path.join(stage, name), name)
PY

echo "Package created: $ZIP_PATH"
