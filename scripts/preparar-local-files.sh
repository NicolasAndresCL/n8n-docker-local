#!/usr/bin/env bash
# Deja ./local-files escribible por el contenedor de n8n.
#
# El contenedor corre como el usuario `node` (uid 1000). En Linux y macOS un
# bind mount conserva el dueño del host, así que si la carpeta pertenece a otro
# uid, n8n no puede escribir en /files y los nodos de archivo fallan con
# "Permission denied" pese a estar el volumen correctamente montado.
#
# En Windows no aplica: Docker Desktop no propaga permisos POSIX a los bind
# mounts, cualquier ruta es escribible desde el contenedor.
#
# Es idempotente: si ya está bien, no hace nada.
set -euo pipefail

cd "$(dirname "$0")/.."

UID_N8N=1000

case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
        echo 'Windows: Docker Desktop ignora los permisos POSIX, no hay nada que preparar.'
        exit 0
        ;;
esac

mkdir -p local-files

actual="$(stat -c '%u' local-files)"
if [ "$actual" = "$UID_N8N" ]; then
    echo "local-files ya pertenece al uid $UID_N8N, nada que hacer."
    exit 0
fi

echo "local-files pertenece al uid $actual; n8n corre como $UID_N8N. Ajustando..."

if chown -R "$UID_N8N:$UID_N8N" local-files 2>/dev/null; then
    echo 'Listo (sin sudo).'
elif command -v sudo >/dev/null 2>&1 && sudo -n chown -R "$UID_N8N:$UID_N8N" local-files 2>/dev/null; then
    echo 'Listo (con sudo).'
else
    cat >&2 <<'FIN'
No se pudo cambiar el propietario de local-files automaticamente.
Ejecuta a mano:

    sudo chown -R 1000:1000 local-files

Sin esto, los nodos Read/Write File fallaran con "Permission denied".
FIN
    exit 1
fi
