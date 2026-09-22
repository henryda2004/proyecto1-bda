#!/usr/bin/env bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================"
echo " TI-4601 - Proyecto 1"
echo " E3 - Mediciones de latencia"
echo "========================================"

echo
echo "[1/2] Verificando que el clúster esté disponible..."

if ! docker exec ti4601-crdb-1 \
    cockroach sql --insecure \
    --host=crdb-1 \
    --database=ti4601 \
    -e "SELECT 1;" >/dev/null 2>&1; then

    echo "ERROR: El clúster no está disponible."
    echo
    echo "Ejecute primero:"
    echo
    echo "    ./scripts/setup.sh"
    echo
    exit 1
fi

echo "Clúster disponible."

echo
echo "[2/2] Ejecutando mediciones..."

docker compose --profile lab1 run --rm app-crdb \
    python scripts/measure_e3.py

echo
echo "========================================"
echo " E3 completado"
echo "========================================"

echo
echo "Resultado guardado en:"
echo "  evidence/e3_metrics.csv"