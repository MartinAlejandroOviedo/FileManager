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

# Build rpm (optional if rpmbuild is available)
RPMBUILD_BIN=$(command -v rpmbuild 2>/dev/null || true)
if [ -z "$RPMBUILD_BIN" ]; then
  echo "Aviso: rpmbuild no esta disponible en PATH, se omite la generacion de RPM." >&2
  exit 0
fi

RPM_TOPDIR="/tmp/${PKG_NAME}_${VERSION}_rpm"
RPM_BUILDROOT="${RPM_TOPDIR}/BUILDROOT"
RPM_SPECS="${RPM_TOPDIR}/SPECS"
RPM_RPMS="${RPM_TOPDIR}/RPMS"
RPM_DBPATH="${RPM_TOPDIR}/rpmdb"

rm -rf "$RPM_TOPDIR"
mkdir -p "$RPM_BUILDROOT" "$RPM_SPECS" "$RPM_RPMS" "$RPM_DBPATH"

CHANGELOG_DATE=$(LC_ALL=C date +"%a %b %d %Y")

SPEC_FILE="${RPM_SPECS}/${PKG_NAME}.spec"
cat > "$SPEC_FILE" <<EOF
Name: ${PKG_NAME}
Version: ${VERSION}
Release: 1%{?dist}
Summary: NiceOS File Manager
License: MIT
BuildArch: x86_64

%description
NiceOS File Manager.
File manager for NiceOS.

%prep
# No sources to unpack

%build
# Nothing to build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/lib/${APP_NAME}
cp -a ${BUILD_DIR}/* %{buildroot}/usr/lib/${APP_NAME}/
mkdir -p %{buildroot}/usr/bin
ln -s /usr/lib/${APP_NAME}/${APP_NAME} %{buildroot}/usr/bin/${APP_NAME}
mkdir -p %{buildroot}/usr/share/applications
cat > %{buildroot}/usr/share/applications/${PKG_NAME}.desktop <<DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=${APP_TITLE}
Comment=NiceOS File Manager
Exec=/usr/lib/${APP_NAME}/${APP_NAME}
Icon=${APP_NAME}
Terminal=false
Categories=Utility;FileManager;
StartupNotify=true
DESKTOP_EOF
mkdir -p %{buildroot}/usr/share/icons/hicolor
if [ -d "${ROOT_DIR}/assets/icon/hicolor" ]; then
  cp -a ${ROOT_DIR}/assets/icon/hicolor/* %{buildroot}/usr/share/icons/hicolor/
fi
mkdir -p %{buildroot}/usr/share/licenses/${PKG_NAME}
cp -a ${ROOT_DIR}/LICENSE %{buildroot}/usr/share/licenses/${PKG_NAME}/LICENSE

%files
%license /usr/share/licenses/${PKG_NAME}/LICENSE
/usr/lib/${APP_NAME}
/usr/bin/${APP_NAME}
/usr/share/applications/${PKG_NAME}.desktop
/usr/share/icons/hicolor

%changelog
* ${CHANGELOG_DATE} ${MAINTAINER_NAME} <${MAINTAINER_EMAIL}> - ${VERSION}-1
- Release
EOF

"$RPMBUILD_BIN" -bb "$SPEC_FILE" --define "_topdir ${RPM_TOPDIR}" --define "_dbpath ${RPM_DBPATH}"

RPM_OUTPUT=$(find "$RPM_RPMS" -type f -name "${PKG_NAME}-${VERSION}-*.rpm" | head -n1 || true)
if [ -z "$RPM_OUTPUT" ]; then
  echo "No se pudo localizar el RPM generado." >&2
  exit 1
fi

OUTPUT_RPM="${ROOT_DIR}/releases/$(basename "$RPM_OUTPUT")"
mkdir -p "$(dirname "$OUTPUT_RPM")"
cp -f "$RPM_OUTPUT" "$OUTPUT_RPM"

echo "RPM generado en: $OUTPUT_RPM"
