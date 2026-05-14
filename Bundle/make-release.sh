#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>  (e.g. 0.1.0)" >&2
    exit 1
fi

echo "==> Building..."
swift build -c release --package-path "$ROOT"

echo "==> Packaging .app..."
bash "$ROOT/Bundle/make-app.sh"

echo "==> Creating DMG..."
DMG_DIR="$(mktemp -d)"
cp -R "$ROOT/MacMenuToolbar.app" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

DMG="$ROOT/MacMenuToolbar-$VERSION.dmg"
hdiutil create -volname "MacMenuToolbar" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG"
rm -rf "$DMG_DIR"

echo "==> Creating GitHub release v$VERSION..."
gh release create "v$VERSION" "$DMG" \
    --repo morshedx/mac-menu-toolbar \
    --title "v$VERSION" \
    --notes "$(cat <<EOF
## Install

1. Download \`MacMenuToolbar-$VERSION.dmg\`
2. Open it and drag **MacMenuToolbar** to Applications
3. Launch — if Gatekeeper blocks it, right-click → Open

## What it shows

- CPU usage + temperature
- RAM usage
- Network upload/download speed (live)

Requires macOS 13+
EOF
)"

rm "$DMG"
echo "==> Released: https://github.com/morshedx/mac-menu-toolbar/releases/tag/v$VERSION"
