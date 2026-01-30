# Contribuir

## Requisitos
- Flutter 3.x
- Linux

## Flujo recomendado
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`

## Estilo
- Mantener UI consistente con NiceOSTheme.
- Evitar dependencias innecesarias.
- Preferir performance en listados grandes.

## Pull Requests
- Describir cambios claramente.
- Adjuntar capturas si hay cambios visuales.

## Empaquetado
- `.deb`: `scripts/build_deb.sh`
- Release: `scripts/release_deb.sh <version>`
