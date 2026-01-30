# File Manager (NiceOS)

File Manager moderno para NiceOS, enfocado en productividad en Linux.

## Características
- Vistas: lista y grilla.
- Panel doble (dual‑pane) con drag & drop.
- Tabs persistentes.
- Búsqueda local y global en /home.
- Panel de detalles con preview (imagen, PDF, audio y video).
- Favoritos, recientes y tags.
- Integración con rclone (montaje de remotos).
- Tema claro/oscuro.

## Requisitos
- Flutter 3.x
- Linux (GTK)
- Opcionales para previews:
  - `pdftoppm` (PDF)
  - `ffmpegthumbnailer` o `ffmpeg` (video thumbnail)
  - `ffprobe` (metadata audio)

## Ejecutar en desarrollo
```bash
flutter pub get
flutter run
```

## Build Linux (release)
```bash
flutter build linux --release
```

## Generar paquete .deb
```bash
scripts/build_deb.sh
```
Genera el paquete en `releases/`.

## Release con versión
```bash
scripts/release_deb.sh 0.1.1
```
- Actualiza `pubspec.yaml`.
- Agrega entrada básica al `CHANGELOG.md`.
- Construye el .deb en `releases/`.

## Estructura
- `lib/ui`: interfaz y pantallas.
- `lib/core`: servicios de filesystem, previews.
- `lib/models`: modelos de datos.
- `lib/utils`: helpers.
- `assets/`: iconos y lottie.

## Estado
Proyecto en evolución; PRs y mejoras visuales son bienvenidas.
