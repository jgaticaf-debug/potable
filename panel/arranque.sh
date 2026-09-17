#!/bin/sh
set -e

# Vite incrusta sus variables al compilar, asi que la URL del API no puede
# venir de ahi si queremos cambiarla sin reconstruir. Se escribe aqui, con la
# variable que el proveedor si entrega al arrancar el contenedor.
printf 'window.__API_URL__ = "%s";
' "${VITE_API_URL:-}" > /app/dist/config.js
echo "[panel] API: ${VITE_API_URL:-(sin definir, se usara el valor del build)}"

exec serve dist -s -l "${PORT:-3000}"
