#!/usr/bin/env bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

docker compose --profile lab1 down -v

echo "========================================"
echo " TI-4601 - Proyecto 1"
echo " Configuración del clúster CockroachDB"
echo "========================================"

echo
echo "[1/7] Levantando el clúster..."
docker compose --profile lab1 up -d

echo
echo "[2/7] Esperando a que CockroachDB esté disponible..."

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
echo "[3/7] Configurando las regiones..."
docker exec -i ti4601-crdb-1 \
    cockroach sql --insecure --host=crdb-1 \
    --database=ti4601 < sql/regions.sql

echo
echo "[4/7] Creando las tablas..."
docker exec -i ti4601-crdb-1 \
    cockroach sql --insecure --host=crdb-1 \
    --database=ti4601 < sql/schema.sql

echo
echo "[5/7] Cargando los datos..."
docker cp sql/seed.sql ti4601-crdb-1:/tmp/seed.sql

docker exec ti4601-crdb-1 \
    cockroach sql --insecure --host=crdb-1 \
    --database=ti4601 \
    -f //tmp/seed.sql

echo
echo "[6/7] Verificando los datos..."
docker exec ti4601-crdb-1 \
    cockroach sql --insecure --host=crdb-1 \
    --database=ti4601 \
    -e "SELECT region, count(*) FROM pedido GROUP BY region ORDER BY region;"

echo
echo "[7/7] Generando evidencia de E2..."

mkdir -p evidence

# Fecha de la ejecución
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# --------------------------------------------------
# Evidencia 1: Verificación de datos
# --------------------------------------------------

{
    echo "========================================"
    echo " TI-4601 - Proyecto 1"
    echo " E2 - Verificación de datos"
    echo " Fecha: $TIMESTAMP"
    echo "========================================"
    echo

    echo "Cantidad de pedidos por región:"
    echo

    docker exec ti4601-crdb-1 \
        cockroach sql --insecure --host=crdb-1 \
        --database=ti4601 \
        -e "SELECT region, count(*) FROM pedido GROUP BY region ORDER BY region;"
} > evidence/verification.txt

# --------------------------------------------------
# Evidencia 2: Definición de las tablas
# --------------------------------------------------

{
    echo "========================================"
    echo " TI-4601 - Proyecto 1"
    echo " E2 - SHOW CREATE TABLE"
    echo " Fecha: $TIMESTAMP"
    echo "========================================"
    echo

    echo "===== producto ====="
    echo

    docker exec ti4601-crdb-1 \
        cockroach sql --insecure --host=crdb-1 \
        --database=ti4601 \
        -e "SHOW CREATE TABLE producto;"

    echo
    echo "===== stock ====="
    echo

    docker exec ti4601-crdb-1 \
        cockroach sql --insecure --host=crdb-1 \
        --database=ti4601 \
        -e "SHOW CREATE TABLE stock;"

    echo
    echo "===== pedido ====="
    echo

    docker exec ti4601-crdb-1 \
        cockroach sql --insecure --host=crdb-1 \
        --database=ti4601 \
        -e "SHOW CREATE TABLE pedido;"
} > evidence/show_create.txt

# --------------------------------------------------
# Evidencia 3: Distribución física de rangos
# --------------------------------------------------

{
    echo "========================================"
    echo " TI-4601 - Proyecto 1"
    echo " E2 - SHOW RANGES"
    echo " Fecha: $TIMESTAMP"
    echo "========================================"
    echo

    echo "===== producto ====="
    echo

    docker exec ti4601-crdb-1 \
        cockroach sql --insecure --host=crdb-1 \
        --database=ti4601 \
        -e "SHOW RANGES FROM TABLE producto;"

    echo
    echo "===== stock ====="
    echo

    docker exec ti4601-crdb-1 \
        cockroach sql --insecure --host=crdb-1 \
        --database=ti4601 \
        -e "SHOW RANGES FROM TABLE stock;"

    echo
    echo "===== pedido ====="
    echo

    docker exec ti4601-crdb-1 \
        cockroach sql --insecure --host=crdb-1 \
        --database=ti4601 \
        -e "SHOW RANGES FROM TABLE pedido;"
} > evidence/show_ranges.txt

echo
echo "Evidencia generada:"
echo "  - evidence/verification.txt"
echo "  - evidence/show_create.txt"
echo "  - evidence/show_ranges.txt"

echo
echo "========================================"
echo " Configuración completada correctamente"
echo "========================================"