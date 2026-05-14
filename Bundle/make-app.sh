#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/.build/release/MacMenuToolbar"
APP="$ROOT/MacMenuToolbar.app"

if [[ ! -x "$BIN" ]]; then
    echo "Binary not found at $BIN. Run: swift build -c release" >&2
    exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/MacMenuToolbar"
cp "$ROOT/Bundle/Info.plist" "$APP/Contents/Info.plist"

# Flatten SPM resource bundle into Contents/Resources so codesign doesn't choke
RES_BUNDLE="$ROOT/.build/release/MacMenuToolbar_MacMenuToolbar.bundle"
if [[ -d "$RES_BUNDLE" ]]; then
    cp -R "$RES_BUNDLE/." "$APP/Contents/Resources/"
fi

codesign --force --deep --sign - "$APP"

echo "Built: $APP"
