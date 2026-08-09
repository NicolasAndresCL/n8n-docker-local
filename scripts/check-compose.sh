#!/usr/bin/env bash
# Guardia de configuración del compose de n8n.
#
# No comprueba estilo: comprueba las cuatro cosas cuya ausencia ya causó (o
# habría causado) un incidente real en este proyecto.
#
# Uso:  scripts/check-compose.sh [ruta-al-compose]
set -euo pipefail

COMPOSE="${1:-docker-compose.yml}"
fallos=0

fallo() {
    printf '  [FALLO] %s\n' "$1" >&2
    fallos=$((fallos + 1))
}

ok() {
    printf '  [ok]    %s\n' "$1"
}

if [ ! -f "$COMPOSE" ]; then
    printf 'No existe el archivo: %s\n' "$COMPOSE" >&2
    exit 2
fi

printf 'Verificando %s\n' "$COMPOSE"

# 1. El volumen de datos debe ser externo. Sin esto Compose crea un volumen
#    nuevo con el prefijo del proyecto y n8n arranca vacío: parece una pérdida
#    total de workflows y credenciales.
if grep -qE '^\s*n8n_data:\s*$' "$COMPOSE" && \
   grep -A2 -E '^\s*n8n_data:\s*$' "$COMPOSE" | grep -qE '^\s*external:\s*true\s*$'; then
    ok 'n8n_data declarado como external: true'
else
    fallo 'n8n_data NO es external: true -> Compose crearia un volumen vacio y n8n arrancaria sin los workflows'
fi

# 2. Versión fijada. Con :latest, un `docker compose pull` migra el esquema de
#    la base a una versión nueva sin decisión consciente y sin vuelta atrás.
if grep -qE '^\s*image:\s*\S*n8n\S*:latest\s*$' "$COMPOSE"; then
    fallo 'la imagen usa :latest -> fijar una version concreta (ej. 2.28.7)'
elif grep -qE '^\s*image:\s*\S*n8n\S*:[0-9]+\.[0-9]+\.[0-9]+\s*$' "$COMPOSE"; then
    ok 'imagen de n8n con version fijada'
else
    fallo 'no se encontro una imagen de n8n con version semantica fijada'
fi

# 3. Si se monta /files, hace falta autorizarlo explícitamente: n8n 2.x
#    restringe el acceso a disco a ~/.n8n-files por defecto y los nodos
#    Read/Write File fallan aunque el volumen esté montado correctamente.
if grep -qE ':/files\s*$' "$COMPOSE"; then
    if grep -qE '^\s*N8N_RESTRICT_FILE_ACCESS_TO:\s*/files\s*$' "$COMPOSE"; then
        ok '/files montado y autorizado con N8N_RESTRICT_FILE_ACCESS_TO'
    else
        fallo 'se monta /files pero falta N8N_RESTRICT_FILE_ACCESS_TO=/files -> los nodos de archivo fallaran con access denied'
    fi
fi

# 4. Disponibilidad: sin restart no vuelve tras reiniciar el equipo, y sin
#    healthcheck "arriba" solo significa que el proceso existe.
if grep -qE '^\s*restart:\s*unless-stopped\s*$' "$COMPOSE"; then
    ok 'restart: unless-stopped'
else
    fallo 'falta restart: unless-stopped'
fi

if grep -qE '^\s*healthcheck:\s*$' "$COMPOSE"; then
    ok 'healthcheck definido'
else
    fallo 'falta healthcheck'
fi

if [ "$fallos" -gt 0 ]; then
    printf '\n%s comprobacion(es) fallida(s) en %s\n' "$fallos" "$COMPOSE" >&2
    exit 1
fi

printf 'Todo correcto.\n'
