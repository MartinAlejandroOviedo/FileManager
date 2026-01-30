# Releases

## Versionado
SemVer: `MAJOR.MINOR.PATCH`.

## Pasos manuales
1. Actualizar `pubspec.yaml` con la nueva versión.
2. Agregar entrada en `CHANGELOG.md`.
3. Ejecutar pruebas:
   - `flutter analyze`
   - `flutter test`
4. Crear tag:
   - `git tag vX.Y.Z`
5. Subir tag al repo.

## Release automático
```bash
scripts/release_deb.sh 0.1.1
```
- Actualiza versión y changelog.
- Construye el .deb.
- Output en `releases/`.

## Build directo
```bash
scripts/build_deb.sh
```
