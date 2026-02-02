# File Manager (NiceOS)

File Manager moderno para NiceOS, enfocado en productividad en Linux.

## Descargas
- Paquetes .deb: https://github.com/MartinAlejandroOviedo/FileManager/tree/main/releases

## Capturas

![Vista principal](assets/screenshot/Captura%20de%20pantalla_20260129_220017.png)
![Dual pane + detalles](assets/screenshot/Captura%20de%20pantalla_20260129_220237.png)
![Preview y panel derecho](assets/screenshot/Captura%20de%20pantalla_20260129_220458.png)

## Características
- Vistas: lista, grilla y columnas.
- Panel doble (dual‑pane) con drag & drop (poco común en Linux).
- Copy/paste como root (útil para operaciones de sistema).
- Tabs persistentes por carpeta.
- Búsqueda local y global en /home.
- Panel de detalles con preview (imagen, PDF, audio y video).
- Favoritos, recientes y tags.
- Integración con rclone (montaje de remotos).
- Tema claro/oscuro con estilo NiceOS.

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

## Generar paquete .rpm
```bash
scripts/build_deb.sh
```
Si `rpmbuild` está disponible, también genera el RPM en `releases/`.

## Release con versión
```bash
scripts/release_deb.sh 0.1.2
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
