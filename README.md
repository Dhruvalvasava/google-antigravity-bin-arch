# Google Antigravity for Arch Linux (Local Build)

Este proyecto permite generar un paquete de Arch Linux para **Google Antigravity**, el nuevo IDE de Google basado en IA.

Utiliza Docker para obtener la última versión disponible desde el repositorio oficial de Debian de Google, asegurando que siempre instales la versión más reciente sin ensuciar tu sistema con repositorios externos.

## Requisitos

- Docker
- Herramientas de compilación de Arch (`base-devel`)

## Instrucciones

1. Ejecuta el script de actualización para obtener la última versión y actualizar el `PKGBUILD`:

   ```bash
   ./update.sh
   ```

   Este script:
   - Construye una imagen Docker mínima.
   - Consulta el repositorio APT de Google Antigravity.
   - Obtiene la URL del `.deb` y su hash SHA256.
   - Actualiza `package/PKGBUILD` con estos datos.

2. Construye e instala el paquete:

   ```bash
   cd package
   makepkg -si
   ```

## Estructura

- `Dockerfile`: Define el entorno para comprobar la versión (Ubuntu + curl + apt).
- `scripts/check-antigravity-version.sh`: Script que se ejecuta dentro del contenedor para encontrar la versión y URL.
- `update.sh`: Orquestador que ejecuta Docker y actualiza el PKGBUILD.
- `package/PKGBUILD`: Script de empaquetado de Arch Linux.

## Nota

Este es un paquete no oficial. Google Antigravity es marca registrada de Google.
El paquete extrae el contenido del `.deb` oficial y lo instala en `/usr/share/antigravity`.
