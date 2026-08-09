#!/usr/bin/env bash
# Deja ./local-files escribible por el contenedor de n8n SIN quitarle la
# escritura al usuario del host.
#
# El contenedor corre como el usuario `node` (uid 1000). En Linux y macOS un
# bind mount conserva dueño y permisos del host, así que si la carpeta pertenece
# a otro uid y no concede escritura a terceros, n8n falla con "Permission
# denied" al escribir en /files.
#
# Se usa `chmod`, no `chown`: cambiar el propietario a 1000 resolvería el acceso
# del contenedor y se lo quitaría al usuario del host, que es justo el otro lado
# del intercambio (y además requeriría root). Con chmod, el dueño sigue siendo
# el usuario del host y el contenedor entra por los permisos de "otros".
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

propietario="$(stat -c '%u' local-files)"

# Caso habitual en un Linux de escritorio: el primer usuario tambien es uid
# 1000, el mismo con el que corre n8n. No hay nada que ajustar.
if [ "$propietario" = "$UID_N8N" ]; then
    echo "local-files ya pertenece al uid $UID_N8N (el mismo de n8n), nada que hacer."
    exit 0
fi

permisos="$(stat -c '%a' local-files)"
if [ "${permisos: -1}" = '7' ]; then
    echo "local-files ya concede acceso completo a otros usuarios ($permisos), nada que hacer."
    exit 0
fi

echo "local-files pertenece al uid $propietario y n8n corre como $UID_N8N."
echo "Concediendo acceso a otros usuarios sin cambiar el propietario..."

# a+rwX: la X mayuscula pone el bit de ejecucion solo en directorios, no en los
# archivos sueltos, que no tienen por que volverse ejecutables.
chmod -R a+rwX local-files

nuevos="$(stat -c '%a' local-files)"
if [ "${nuevos: -1}" != '7' ]; then
    echo "No se pudo hacer local-files accesible (permisos: $nuevos)." >&2
    echo 'Ejecuta a mano:  chmod -R a+rwX local-files' >&2
    exit 1
fi

echo "Listo (permisos: $nuevos)."
