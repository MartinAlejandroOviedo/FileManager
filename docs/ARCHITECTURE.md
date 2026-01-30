# Arquitectura

## Capas principales
- `lib/core`: servicios de archivos, acceso al sistema, operaciones (copiar, mover, borrar), previews.
- `lib/ui`: widgets, pantallas y layout principal.
- `lib/models`: modelos de datos (`FileItem`, etc).
- `lib/utils`: helpers (búsqueda, formatos, filtros).

## Flujo de datos
- `MainScreen` controla navegación, selección y vista.
- `FileService` ejecuta acciones sobre el filesystem y genera previews.
- UI reacciona a `setState` y refresca listados.

## Persistencia
- Configuración y tabs: `~/.config/file_manager/settings.json`.
- Places personalizados: `~/.config/file_manager/places.json`.

## Integraciones externas
- `rclone` para remotos (montaje/desmontaje).
- `xdg-open` para abrir archivos.
- `pdftoppm` para preview PDF.
- `ffmpegthumbnailer`/`ffmpeg` para thumbnails de video.
- `ffprobe` para metadata de audio.
