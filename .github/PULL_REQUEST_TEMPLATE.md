## Qué cambia

<!-- Descripción breve del cambio y por qué. -->

## Cómo se verificó

- [ ] `./verificar.sh` pasa en local
- [ ] `docker compose up -d` deja el contenedor en `healthy`

## Datos

- [ ] `n8n_data` sigue declarado `external: true`
- [ ] Si el cambio toca almacenamiento, hay respaldo previo del volumen

## Secretos

- [ ] `git status` revisado: no se incluyen `client_secret_*.json`, códigos 2FA,
      `.env` ni respaldos del volumen
