#!/usr/bin/env bash
# Prueba preparar-local-files.sh en un Linux de verdad, dentro de un contenedor.
#
# Existe porque el fallo que corrige es invisible en la máquina de desarrollo:
# Docker Desktop en Windows no propaga permisos POSIX, así que allí cualquier
# carpeta es escribible y el script parece correcto pase lo que pase. Sin esta
# prueba, la única forma de comprobarlo era pushear y esperar al CI.
#
# Reproduce el escenario del runner: la carpeta pertenece al usuario del host
# (uid 1001) y n8n corre como uid 1000. Después exige que AMBOS puedan escribir,
# que es lo que significa "intercambio de archivos".
set -euo pipefail

cd "$(dirname "$0")/.."

ruta_repo="$(pwd -W 2>/dev/null || pwd)"

echo 'Simulando un host Linux (carpeta del uid 1001, contenedor del uid 1000)...'

MSYS_NO_PATHCONV=1 docker run --rm \
    -v "${ruta_repo}/scripts/preparar-local-files.sh:/origen/preparar-local-files.sh:ro" \
    debian:stable-slim bash -euo pipefail -c '
        mkdir -p /trabajo/scripts /trabajo/local-files
        cp /origen/preparar-local-files.sh /trabajo/scripts/
        chmod +x /trabajo/scripts/preparar-local-files.sh

        # El checkout del runner pertenece a su usuario, no a root.
        chown -R 1001:1001 /trabajo

        echo "--- Antes: $(stat -c "%u %a" /trabajo/local-files)"

        # El script lo ejecuta el usuario del host, sin privilegios de root.
        setpriv --reuid=1001 --regid=1001 --clear-groups \
            bash /trabajo/scripts/preparar-local-files.sh

        echo "--- Despues: $(stat -c "%u %a" /trabajo/local-files)"

        # 1) El contenedor de n8n (uid 1000) debe poder escribir.
        if ! setpriv --reuid=1000 --regid=1000 --clear-groups \
                sh -c "echo contenedor > /trabajo/local-files/desde-contenedor.txt"; then
            echo "FALLO: el uid 1000 (n8n) no puede escribir en local-files" >&2
            exit 1
        fi

        # 2) El usuario del host debe CONSERVAR la escritura. Este es el caso
        #    que rompio un chown: el contenedor ganaba acceso y el host lo
        #    perdia.
        if ! setpriv --reuid=1001 --regid=1001 --clear-groups \
                sh -c "echo host > /trabajo/local-files/desde-host.txt"; then
            echo "FALLO: el uid 1001 (host) perdio la escritura sobre local-files" >&2
            exit 1
        fi

        # 3) Cada uno debe leer lo que escribio el otro.
        setpriv --reuid=1000 --regid=1000 --clear-groups \
            grep -q host /trabajo/local-files/desde-host.txt
        setpriv --reuid=1001 --regid=1001 --clear-groups \
            grep -q contenedor /trabajo/local-files/desde-contenedor.txt

        # 4) Idempotencia: una segunda pasada no debe romper nada.
        setpriv --reuid=1001 --regid=1001 --clear-groups \
            bash /trabajo/scripts/preparar-local-files.sh

        echo "OK: host y contenedor escriben y se leen mutuamente."
    '

echo 'Prueba de permisos superada.'
