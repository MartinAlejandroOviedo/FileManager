#!/bin/sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PKG_NAME="file-manager"
APP_NAME="file_manager"
APP_TITLE="File Manager"
MAINTAINER_NAME="Martin Alejandro Oviedo"
MAINTAINER_EMAIL="martinoviedo@disroot.org"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  VERSION=$(grep -n "^version:" "$ROOT_DIR/pubspec.yaml" | head -n1 | awk '{print $2}')
fi
if [ -z "$VERSION" ]; then
  echo "No se pudo detectar version en pubspec.yaml" >&2
  exit 1
fi
BUILD_DIR="$ROOT_DIR/build/linux/x64/release/bundle"

FLUTTER_BIN=$(command -v flutter 2>/dev/null || true)
if [ -z "$FLUTTER_BIN" ] && [ -x "/home/martin/flutter/bin/flutter" ]; then
  FLUTTER_BIN="/home/martin/flutter/bin/flutter"
fi
if [ -z "$FLUTTER_BIN" ]; then
  echo "No se encontro flutter en PATH" >&2
  exit 1
fi

if [ ! -x "$BUILD_DIR/$APP_NAME" ]; then
  "$FLUTTER_BIN" build linux --release
fi

PKG_ROOT="/tmp/${PKG_NAME}_${VERSION}"
rm -rf "$PKG_ROOT"
mkdir -p "$PKG_ROOT/DEBIAN"
mkdir -p "$PKG_ROOT/usr/lib/${APP_NAME}"
mkdir -p "$PKG_ROOT/usr/bin"
mkdir -p "$PKG_ROOT/usr/share/applications"
mkdir -p "$PKG_ROOT/usr/share/icons/hicolor"

# Control file
cat > "$PKG_ROOT/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: ${MAINTAINER_NAME} <${MAINTAINER_EMAIL}>
Description: NiceOS File Manager
 File manager for NiceOS.
EOF

# Install bundle
cp -r "$BUILD_DIR"/* "$PKG_ROOT/usr/lib/${APP_NAME}/"

# Symlink to /usr/bin
ln -s "/usr/lib/${APP_NAME}/${APP_NAME}" "$PKG_ROOT/usr/bin/${APP_NAME}"

# Desktop file
cat > "$PKG_ROOT/usr/share/applications/${PKG_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_TITLE}
Comment=NiceOS File Manager
Exec=/usr/lib/${APP_NAME}/${APP_NAME}
Icon=${APP_NAME}
Terminal=false
Categories=Utility;FileManager;
StartupNotify=true
EOF

# Icons
if [ -d "$ROOT_DIR/assets/icon/hicolor" ]; then
  cp -r "$ROOT_DIR/assets/icon/hicolor"/* "$PKG_ROOT/usr/share/icons/hicolor/"
fi

# Permissions
chmod 0644 "$PKG_ROOT/DEBIAN/control"

# Build deb
OUTPUT_DEB="${ROOT_DIR}/releases/${PKG_NAME}_${VERSION}_amd64.deb"
mkdir -p "$(dirname "$OUTPUT_DEB")"
dpkg-deb --root-owner-group --build "$PKG_ROOT" "$OUTPUT_DEB"

echo "DEB generado en: $OUTPUT_DEB"
