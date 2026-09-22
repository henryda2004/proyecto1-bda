import csv
import os
import time

import psycopg


HOST_R1 = "crdb-1"

PORT = 26257
DATABASE = "ti4601"
USER = "root"

WARMUP_RUNS = 10
MEASUREMENT_RUNS = 30

OUTPUT_FILE = "/src/evidence/e3_metrics.csv"


def connect():
    return psycopg.connect(
        host=HOST_R1,
        port=PORT,
        dbname=DATABASE,
        user=USER,
        sslmode="disable",
    )


def percentile(values, p):
    """
    Calcula un percentil mediante interpolación lineal.
    p debe estar entre 0 y 1.
    """
    ordered = sorted(values)

    if not ordered:
        return None

    position = (len(ordered) - 1) * p
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)

    fraction = position - lower

    return (
        ordered[lower]
        + (ordered[upper] - ordered[lower]) * fraction
    )


def execute_and_measure(connection, sql, parameters=None):
    """
    Ejecuta una operación y mide únicamente el tiempo
    de ejecución de la operación desde el cliente.
    """

    start = time.perf_counter()

    with connection.cursor() as cursor:
        cursor.execute(sql, parameters)

    connection.commit()

    end = time.perf_counter()

    return (end - start) * 1000.0


def run_case(name, connection, sql, parameters=None):
    print(f"  {name}")

    # --------------------------------------------------
    # Warm-up
    # --------------------------------------------------

    for _ in range(WARMUP_RUNS):
        execute_and_measure(
            connection,
            sql,
            parameters,
        )

    # --------------------------------------------------
    # Mediciones
    # --------------------------------------------------

    latencies = []

    for _ in range(MEASUREMENT_RUNS):
        latency = execute_and_measure(
            connection,
            sql,
            parameters,
        )

        latencies.append(latency)

    return {
        "case": name,
        "runs": MEASUREMENT_RUNS,
        "warmup": WARMUP_RUNS,
        "p50_ms": percentile(latencies, 0.50),
        "p99_ms": percentile(latencies, 0.99),
        "min_ms": min(latencies),
        "max_ms": max(latencies),
    }


def get_product_id(connection):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT codproducto
            FROM producto
            ORDER BY codproducto
            LIMIT 1;
            """
        )

        row = cursor.fetchone()

    if row is None:
        raise RuntimeError(
            "No se encontró ningún producto en la base de datos."
        )

    return row[0]


def main():

    print()
    print("========================================")
    print(" E3 - Mediciones de latencia")
    print("========================================")
    print()
    print(f"Warm-up: {WARMUP_RUNS}")
    print(f"Corridas por caso: {MEASUREMENT_RUNS}")
    print()

    results = []

    with connect() as connection:

        product_id = get_product_id(connection)

        # ==================================================
        # 1. LECTURA LOCAL
        #
        # Origen: R1 (tienda-a)
        # Fila:   R1 (tienda-a)
        # ==================================================

        results.append(
            run_case(
                "lectura_local_R1",
                connection,
                """
                SELECT unidades
                FROM stock
                WHERE region = 'tienda-a'
                  AND codproducto = %s;
                """,
                (product_id,),
            )
        )

        # ==================================================
        # 2. LECTURA REMOTA
        #
        # Origen: R1 (tienda-a)
        # Fila:   R2 (tienda-b)
        # ==================================================

        results.append(
            run_case(
                "lectura_remota_R1_R2",
                connection,
                """
                SELECT unidades
                FROM stock
                WHERE region = 'tienda-b'
                  AND codproducto = %s;
                """,
                (product_id,),
            )
        )

        # ==================================================
        # 3. ESCRITURA LOCAL
        #
        # Origen: R1 (tienda-a)
        # Fila:   R1 (tienda-a)
        #
        # Se modifica el valor y luego se restaura.
        # ==================================================

        results.append(
            run_case(
                "escritura_local_R1",
                connection,
                """
                UPDATE stock
                SET unidades = CASE
                    WHEN unidades = 10 THEN 11
                    ELSE 10
                END
                WHERE region = 'tienda-a'
                  AND codproducto = %s;
                """,
                (product_id,),
            )
        )

        # ==================================================
        # 4. ESCRITURA QUE CRUZA REGIÓN
        #
        # Origen: R1 (tienda-a)
        # Fila:   R2 (tienda-b)
        #
        # Se modifica el valor y luego se restaura.
        # ==================================================

        results.append(
            run_case(
                "escritura_cross_region_R1_R2",
                connection,
                """
                UPDATE stock
                SET unidades = CASE
                    WHEN unidades = 10 THEN 11
                    ELSE 10
                END
                WHERE region = 'tienda-b'
                  AND codproducto = %s;
                """,
                (product_id,),
            )
        )

    # ==================================================
    # Guardar resultados
    # ==================================================

    os.makedirs(
        os.path.dirname(OUTPUT_FILE),
        exist_ok=True,
    )

    with open(
        OUTPUT_FILE,
        "w",
        newline="",
    ) as file:

        writer = csv.DictWriter(
            file,
            fieldnames=[
                "case",
                "runs",
                "warmup",
                "p50_ms",
                "p99_ms",
                "min_ms",
                "max_ms",
            ],
        )

        writer.writeheader()
        writer.writerows(results)

    print()
    print("Resultados:")
    print()

    for result in results:
        print(
            f"{result['case']}: "
            f"p50={result['p50_ms']:.3f} ms, "
            f"p99={result['p99_ms']:.3f} ms"
        )

    print()
    print(f"Resultados guardados en:")
    print(f"  {OUTPUT_FILE}")
    print()


if __name__ == "__main__":
    main()