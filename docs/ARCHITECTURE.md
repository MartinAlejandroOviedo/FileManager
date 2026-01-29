# Arquitectura

## Capas principales
- `lib/core`: servicios de archivos, acceso al sistema, operaciones (copiar, mover, borrar).
- `lib/ui`: widgets, pantallas y layout principal.
- `lib/models`: modelos de datos (`FileItem`, etc).
- `lib/utils`: helpers (búsqueda, formatos).

## Flujo de datos
- `MainScreen` controla estado de navegación, selección y vista.
- `FileService` ejecuta acciones sobre el filesystem.
- UI reacciona a `setState` y refresca listados.

## Persistencia
- Configuración y tabs guardadas en `~/.config/file_manager/settings.json`.
- Atajos de Places en `~/.config/file_manager/places.json`.

## Integraciones externas
- `rclone` para remotos (montaje/desmontaje).
- `xdg-open` para abrir archivos.
