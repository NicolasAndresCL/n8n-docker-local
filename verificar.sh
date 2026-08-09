#!/usr/bin/env bash
# Reproduce en local el job `lint` de CI, con las mismas herramientas y las
# mismas versiones. Si esto pasa, ese job pasa.
#
# actionlint y yamllint corren en contenedores efímeros: nada que instalar en
# la máquina y misma versión que en CI.
#
# Uso:  ./verificar.sh
set -euo pipefail

cd "$(dirname "$0")"

echo '== 1/4  Sintaxis del compose =='
docker compose config --quiet

echo '== 2/4  Guardia de configuracion =='
bash scripts/check-compose.sh docker-compose.yml

echo '== 3/4  El guardia detecta una config rota (prueba en negativo) =='
if bash scripts/check-compose.sh scripts/fixtures/compose-roto.yml >/dev/null 2>&1; then
    echo 'ERROR: el guardia acepto un compose roto. Esta comprobando la nada.' >&2
    exit 1
fi
echo '  [ok]    el fixture roto es rechazado'

echo '== 4/4  Lint de los workflows de GitHub Actions =='
# En Git Bash (Windows) hay que sortear dos cosas: `pwd` devuelve /c/... que
# Docker Desktop no entiende (de ahí `pwd -W`), y MSYS convierte el `/repo` del
# contenedor en una ruta de Windows si no se desactiva. En Linux, `pwd -W`
# no existe y la variable se ignora, así que el mismo comando sirve en ambos.
ruta_repo="$(pwd -W 2>/dev/null || pwd)"
MSYS_NO_PATHCONV=1 docker run --rm \
    -v "${ruta_repo}:/repo" -w /repo \
    rhysd/actionlint:latest -color

echo
echo 'Verificacion completa: OK'
