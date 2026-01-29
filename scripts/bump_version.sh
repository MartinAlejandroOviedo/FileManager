#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Uso: scripts/bump_version.sh X.Y.Z"
  exit 1
fi

VERSION="$1"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version inválida: $VERSION"
  exit 1
fi

if [[ ! -f pubspec.yaml ]]; then
  echo "No se encontró pubspec.yaml"
  exit 1
fi

sed -i "s/^version: .*/version: ${VERSION}/" pubspec.yaml

echo "Actualizado pubspec.yaml -> ${VERSION}"
echo "Recordá actualizar CHANGELOG.md"
