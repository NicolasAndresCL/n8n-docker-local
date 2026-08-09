# n8n local con Docker

[![CI](https://github.com/NicolasAndresCL/n8n-docker-local/actions/workflows/ci.yml/badge.svg)](https://github.com/NicolasAndresCL/n8n-docker-local/actions/workflows/ci.yml)

Configuración reproducible de [n8n](https://n8n.io) en Docker para uso local:
versión fijada, arranque automático, healthcheck real y un guardia que impide el
error de configuración que hace que n8n arranque sin tus workflows.

| Dato | Valor |
|---|---|
| UI | http://localhost:5678 |
| Imagen | `docker.n8n.io/n8nio/n8n:2.28.7` |
| Datos | volumen Docker `n8n_data` |
| Archivos | `./local-files` ↔ `/files` en el contenedor |

## Uso

```bash
docker compose up -d      # levantar (vuelve solo tras reiniciar el equipo)
docker compose logs -f    # ver logs
docker compose down       # parar — NO borra el volumen ni los workflows
./verificar.sh            # reproducir el lint de CI en local
```

En **Linux y macOS**, una vez tras clonar:

```bash
bash scripts/preparar-local-files.sh
```

El contenedor corre como uid 1000 y un bind mount conserva el dueño del host,
así que sin ese paso los nodos de archivo fallan con *Permission denied*. En
Windows el script no hace nada porque Docker Desktop no propaga permisos POSIX.

Los comandos del CLI de n8n se ejecutan dentro del contenedor:

```bash
docker compose exec n8n n8n list:workflow                          # listar
docker compose exec n8n n8n export:workflow --backup --output=/files/backup/
docker compose exec n8n n8n import:workflow --separate --input=/files/backup/
```

## Dónde viven los datos

Todo lo que importa —workflows, credenciales y la clave de cifrado— está en el
volumen Docker **`n8n_data`**, no en esta carpeta ni dentro del contenedor. Por
eso `docker rm` del contenedor es inofensivo y `docker compose down` no pierde
nada.

El volumen se declara `external: true`. **No quites esa línea**: sin ella
Compose crea un volumen propio con el prefijo del proyecto y n8n arranca vacío,
que se ve exactamente igual que haber perdido todo el trabajo. El guardia de CI
falla si alguien lo intenta.

### Intercambio de archivos

Lo que dejes en `local-files/` aparece dentro del contenedor como `/files`. Usa
rutas absolutas (`/files/datos.csv`) en los nodos Read/Write File.

n8n 2.x restringe el acceso a disco a `~/.n8n-files` por defecto, así que el
compose declara `N8N_RESTRICT_FILE_ACCESS_TO=/files`. Sin esa variable el
montaje existe pero los nodos de archivo fallan con *access denied*.

## Respaldos

```bash
docker run --rm -v n8n_data:/data:ro -v "${PWD}/backups:/backup" alpine \
  tar czf /backup/n8n_data-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .
```

Restaurar:

```bash
docker compose down
docker run --rm -v n8n_data:/data -v "${PWD}/backups:/backup" alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/<archivo>.tar.gz -C /data"
docker compose up -d
```

Los respaldos quedan en `backups/`, ignorada por git.

## CI

Tres jobs, los rápidos primero:

1. **`lint`** — sintaxis del compose, `shellcheck` sobre los scripts, el guardia
   de configuración y `actionlint`. Incluye una prueba en negativo: el CI falla
   si el guardia *acepta* un compose deliberadamente roto, porque un check que
   solo se ha probado en el caso bueno pasaría igual de verde comprobando la
   nada.
2. **`secretos`** — `gitleaks` sobre el historial, más una comprobación de que
   los patrones sensibles de este repo (credenciales OAuth, códigos 2FA,
   respaldos) siguen cubiertos por `.gitignore`.
3. **`smoke`** — levanta n8n de verdad con un volumen vacío, espera a `healthy`,
   comprueba que el puerto publicado devuelve 200, que `/files` funciona en
   ambas direcciones y que **un workflow importado sobrevive a destruir y
   recrear el contenedor**. Esa última es la regresión que protege contra perder
   el `external: true`.

El guardia (`scripts/check-compose.sh`) verifica cuatro cosas cuya ausencia ya
causó o habría causado un incidente: volumen no externo, imagen en `:latest`,
`/files` montado sin autorizar, y falta de `restart`/`healthcheck`.

### Hook de pre-commit

```bash
git config core.hooksPath .githooks
```

Corre `./verificar.sh` solo cuando el commit toca el compose, los scripts o los
workflows: un commit de documentación no espera a que arranquen contenedores.

## Estructura

```
docker-compose.yml               configuración del servicio
verificar.sh                     reproduce el job de lint en local
local-files/                     intercambio de archivos con el contenedor
scripts/check-compose.sh         guardia de configuración
scripts/preparar-local-files.sh  permisos del bind mount (Linux y macOS)
scripts/fixtures/                compose roto y workflow de prueba, para los
                                 checks en negativo y de persistencia
.githooks/pre-commit             verificación antes de commitear
.github/workflows/ci.yml         pipeline
```

## Nota sobre credenciales

Este repositorio es público y no incluye credenciales: `.gitignore` excluye
`client_secret_*.json`, códigos 2FA, respaldos del volumen y los exports de
workflows del curso (que contienen datos personales de terceros).

Si trabajas sobre esta carpeta, mantén los archivos de credenciales fuera del
árbol del proyecto.
