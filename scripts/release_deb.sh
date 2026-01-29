#!/bin/sh
set -eu

# Uso: scripts/release_deb.sh 1.2.3
NEW_VERSION="${1:-}"
if [ -z "$NEW_VERSION" ]; then
  echo "Uso: $0 <version>" >&2
  exit 1
fi

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

# Update pubspec.yaml version
if grep -q "^version:" "$ROOT_DIR/pubspec.yaml"; then
  sed -i "s/^version:.*/version: ${NEW_VERSION}/" "$ROOT_DIR/pubspec.yaml"
else
  echo "version: ${NEW_VERSION}" >> "$ROOT_DIR/pubspec.yaml"
fi

# Build deb
"${ROOT_DIR}/scripts/build_deb.sh" "$NEW_VERSION"

# Update CHANGELOG (simple append)
if [ -f "$ROOT_DIR/CHANGELOG.md" ]; then
  DATE=$(date +%Y-%m-%d)
  printf "\n## ${NEW_VERSION} - ${DATE}\n- Release\n" >> "$ROOT_DIR/CHANGELOG.md"
fi

echo "Release completado: ${NEW_VERSION}"
