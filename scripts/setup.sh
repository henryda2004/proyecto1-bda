#!/usr/bin/env bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "========================================"
echo " TI-4601 - Proyecto 1"
echo " Configuración del clúster CockroachDB"
echo "========================================"

echo
echo "[1/6] Levantando el clúster..."
docker compose --profile lab1 up -d

echo
echo "[2/6] Esperando a que CockroachDB esté disponible..."

for i in $(seq 1 90); do
    if docker exec ti4601-crdb-1 \
        cockroach sql --insecure --host=crdb-1 \
        -e "SELECT 1;" >/dev/null 2>&1; then
        echo "CockroachDB está disponible."
        break
    fi

    if [ "$i" -eq 90 ]; then
        echo "ERROR: CockroachDB no estuvo disponible después de 90 segundos."
        exit 1
    fi

    sleep 1
done

echo
echo "[3/6] Configurando las regiones..."
docker exec -i ti4601-crdb-1 \
    cockroach sql --insecure --host=crdb-1 \
    --database=ti4601 < sql/regions.sql

echo
echo "[4/6] Creando las tablas..."
docker exec -i ti4601-crdb-1 \
    cockroach sql --insecure --host=crdb-1 \
    --database=ti4601 < sql/schema.sql

echo
echo "[5/6] Cargando los datos..."
docker cp sql/seed.sql ti4601-crdb-1:/tmp/seed.sql

docker exec ti4601-crdb-1 \
    cockroach sql --insecure --host=crdb-1 \
    --database=ti4601 \
    -f //tmp/seed.sql

echo
echo "[6/6] Verificando los datos..."
docker exec ti4601-crdb-1 \
    cockroach sql --insecure --host=crdb-1 \
    --database=ti4601 \
    -e "SELECT region, count(*) FROM pedido GROUP BY region ORDER BY region;"

echo
echo "========================================"
echo " Configuración completada correctamente"
echo "========================================"