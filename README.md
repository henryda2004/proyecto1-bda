# Proyecto 1 — Base de Datos Distribuida a Pequeña Escala

**Curso:** TI-4601 Bases de Datos Avanzadas

**Institución:** Instituto Tecnológico de Costa Rica

**Dominio:** Opción B — Comercio / Inventario Multi-tienda

**Motor:** CockroachDB v24.3.0 (clúster de 3 nodos)

---

## Regiones

| Región | Nodo | Rol |
| --- | --- | --- |
| `tienda-a` | crdb-1 | Tienda regional |
| `tienda-b` | crdb-2 | Tienda regional |
| `cd-central` | crdb-3 | Centro de distribución |

---

## Qué hace cada archivo

| Archivo | Qué hace |
| --- | --- |
| `docker-compose.yml` | Define los tres nodos de CockroachDB, cada uno con su localidad de región |
| `Dockerfile` | Construye la imagen del cliente Python con psycopg |
| `requirements.txt` | Dependencias de Python |
| `sql/regions.sql` | Configura la base como multi-región. Se corre antes del schema |
| `sql/schema.sql` | Crea las tres tablas. `producto` es GLOBAL, `stock` y `pedido` son REGIONAL BY ROW |
| `sql/seed.sql` | Carga 10 productos, 30 filas de stock y 300 pedidos |
| `scripts/setup.sh` | Elimina un clúster si existía uno, luego vuelve a levantar y configurar el clúster, crea las tablas, carga los datos y genera la evidencia de E2 |
| `evidence/verification.txt` | Evidencia de la cantidad de pedidos por región |
| `evidence/show_create.txt` | Evidencia de la configuración de localidad de las tablas mediante `SHOW CREATE TABLE` |
| `evidence/show_ranges.txt` | Evidencia de la distribución de rangos y réplicas mediante `SHOW RANGES` |
| `scripts/measure_e3.py` | Ejecuta las cuatro mediciones de latencia y calcula p50 y p99 |
| `scripts/measure_e3.sh` | Verifica el clúster y ejecuta automáticamente las mediciones de E3 |
| `evidence/e3_metrics.csv` | Guarda los resultados de las mediciones de E3 |

| `sql/e4_probe.sql` | Crea la tabla de control de E4 con tres réplicas votantes |
| `scripts/e4_probe.py` | Ejecuta escrituras continuas y calcula el RTO después de detener un nodo |
| `evidence/e4-chaos.csv` | Guarda cada intento de escritura, su timestamp, estado y latencia |
| `evidence/e4-probe.txt` | Contiene la salida completa de la prueba y el RTO observado |
| `evidence/e4-stop.txt` | Registra los timestamps de la detención de `crdb-2` |
| `evidence/e4-rpo.txt` | Verifica la fila final utilizada para determinar el RPO |


---

## Cómo levantar el proyecto

Se ejecuta el script de configuración:

```bash
./scripts/setup.sh
```

El script realiza automáticamente los siguientes pasos:
1. Se eliminan los contenedores y volúmenes del clúster, para realizar una configuración limpia y reproducible del laboratorio.
2. Levanta los tres nodos de CockroachDB.
3. Espera hasta que CockroachDB esté disponible.
4. Configura las regiones de la base de datos.
5. Crea las tablas del esquema.
6. Carga los datos de prueba.
7. Verifica la cantidad de pedidos por región.
8. Genera automáticamente la evidencia de E2.

Al finalizar, debe aparecer una distribución de:

```text
region      count
cd-central  100
tienda-a    100
tienda-b    100
```

Por lo tanto, se cargan 300 pedidos en total, con 100 pedidos asociados a cada región.


### Evidencia de E2

La ejecución de `setup.sh` genera tres archivos dentro de `evidence/`:

```text
evidence/
├── show_create.txt
├── show_ranges.txt
└── verification.txt
```

#### `show_create.txt`

Contiene la salida de `SHOW CREATE TABLE` para las tres tablas.

La evidencia confirma que:

- `producto` utiliza `LOCALITY GLOBAL`.
- `stock` utiliza `LOCALITY REGIONAL BY ROW AS region`.
- `pedido` utiliza `LOCALITY REGIONAL BY ROW AS region`.

Esto permite verificar que la localidad definida en el diseño fue implementada en el esquema de CockroachDB.

#### `show_ranges.txt`

Contiene la salida de:

```sql
SHOW RANGES FROM TABLE producto;
SHOW RANGES FROM TABLE stock;
SHOW RANGES FROM TABLE pedido;
```

La salida permite observar las réplicas y sus localidades. En la ejecución actual se observan réplicas asociadas a:

```text
region=tienda-a,zone=a
region=tienda-b,zone=a
region=cd-central,zone=a
```

para los rangos mostrados.

#### `verification.txt`

Contiene la verificación de los pedidos cargados:

```text
cd-central  100
tienda-a    100
tienda-b    100
```

Esta evidencia comprueba que los datos de prueba fueron cargados correctamente en las tres regiones.

---
### Fallo de sitio, E4
Para esta prueba se utilizó la tabla de control `e4_probe`, almacenada en la base de datos `ti4601_e4`. La tabla se configuró con tres réplicas votantes, una en cada nodo,para el caso en la que un n nodo falle.

La falla de sitio se simuló deteniendo el contenedor `crdb-2`, correspondiente a la región `tienda-b`. Antes de ejecutar la prueba, se verificó que el rango tuviera las réplicas `{1,2,3}` y que el nodo 2 fuera el poseedor del lease.

### Preparación

La tabla de control se crea con:

```bash
docker compose exec -T crdb-1 ./cockroach sql \
  --insecure \
  --host=crdb-1 \
  < sql/e4_probe.sql
```

La distribución de las réplicas se consulta con:

```bash
docker compose exec -T crdb-1 ./cockroach sql \
  --insecure \
  --database=ti4601_e4 \
  -e "SELECT range_id, lease_holder, voting_replicas FROM [SHOW RANGES FROM TABLE e4_probe WITH DETAILS];"
```

En la ejecución realizada, el rango utilizado fue el número 100. El lease se colocó en el nodo 2 mediante:

```bash
docker compose exec -T crdb-1 ./cockroach sql \
  --insecure \
  --database=ti4601_e4 \
  -e "ALTER RANGE 100 RELOCATE LEASE TO 2;"
```

Si el identificador del rango cambia después de reconstruir el clúster, debe utilizarse el valor mostrado por `SHOW RANGES`.

### Ejecución

En una primera terminal se ejecuta la sonda de escrituras:

```bash
rm -f evidence/e4-stop.epoch

docker compose --profile lab1 run --rm --no-deps \
  -e PGDATABASE=ti4601_e4 \
  app-crdb python -u scripts/e4_probe.py \
  --duration 60 \
  --interval 0.5 \
  --signal-file evidence/e4-stop.epoch \
  --csv evidence/e4-chaos.csv \
  | tee evidence/e4-probe.txt
```

Mientras la sonda realiza escrituras, en una segunda terminal se detiene el nodo:

```bash
echo "Inicio de la falla: $(date -Iseconds)" \
  | tee evidence/e4-stop.txt

docker compose --profile lab1 stop -t 0 crdb-2 2>&1 \
  | tee -a evidence/e4-stop.txt

date +%s.%N > evidence/e4-stop.epoch

echo "Nodo detenido: $(date -Iseconds)" \
  | tee -a evidence/e4-stop.txt
```

Después de finalizar la sonda, se verifica que la última escritura confirmada siga almacenada:

```bash
echo "Verificación de RPO: $(date -Iseconds)" \
  | tee evidence/e4-rpo.txt

docker compose exec -T crdb-1 ./cockroach sql \
  --insecure \
  --database=ti4601_e4 \
  -e "SELECT id, version, updated_at FROM e4_probe;" \
  | tee -a evidence/e4-rpo.txt
```

Finalmente, se vuelve a levantar el nodo y se elimina el archivo temporal de señal:

```bash
docker compose --profile lab1 start crdb-2
rm -f evidence/e4-stop.epoch
```

## Mediciones de E3

Con el clúster configurado, las mediciones se ejecutan con:

```bash
bash scripts/measure_e3.sh
```

El script realiza 10 corridas de calentamiento y 30 corridas válidas para cada caso:

- Lectura local en `tienda-a`.
- Lectura remota desde `tienda-a` hacia `tienda-b`.
- Escritura local en `tienda-a`.
- Escritura que cruza desde `tienda-a` hacia `tienda-b`.

Los resultados de p50 y p99 se guardan en `evidence/e3_metrics.csv`.

### Resultados obtenidos

| Operación | Desde región | p50 (ms) | p99 (ms) | Corridas | Notas |
| --- | --- | ---: | ---: | ---: | --- |
| Lectura local | R1 → R1 | 2.398 | 2.801 | 30 | Fila ubicada en `tienda-a` |
| Lectura remota | R1 → R2 | 2.432 | 3.091 | 30 | Fila ubicada en `tienda-b` |
| Escritura local | R1 → R1 | 26.624 | 99.350 | 30 | Actualización en `tienda-a` |
| Escritura que cruza región | R1 → R2 | 28.858 | 63.727 | 30 | Actualización en `tienda-b` |

---


## Para apagar todo

Para detener los contenedores sin eliminar los volúmenes:

```bash
docker compose --profile lab1 down
```

Para realizar nuevamente una configuración completamente limpia:

```bash
./scripts/setup.sh
```

---

## Estado actual

Implementado para E2:

- Clúster de tres nodos de CockroachDB.
- Tres regiones configuradas:
  - `tienda-a` → `crdb-1`
  - `tienda-b` → `crdb-2`
  - `cd-central` → `crdb-3`
- `producto` implementada como tabla `GLOBAL`.
- `stock` implementada como `REGIONAL BY ROW AS region`.
- `pedido` implementada como `REGIONAL BY ROW AS region`.
- 10 productos cargados.
- 30 filas de stock cargadas.
- 300 pedidos cargados, 100 por región.
- `SHOW CREATE TABLE` confirma la localidad configurada en cada tabla.
- `SHOW RANGES` permite verificar la distribución de réplicas y sus localidades.
- El procedimiento completo de configuración y generación de evidencia está automatizado mediante `scripts/setup.sh`.


Implementado para E3:

- Script automatizado para ejecutar las mediciones.
- Lectura local y lectura remota.
- Escritura local y escritura que cruza región.
- 10 corridas de calentamiento.
- 30 corridas válidas por caso.
- Cálculo de p50 y p99.
- Resultados almacenados en `evidence/e3_metrics.csv`.

Implementado para E4:

- Tabla de control con tres réplicas votantes.
- Falla simulada mediante la detención de `crdb-2`.
- Sonda de escrituras continuas con timestamps.
- RTO observado de aproximadamente 12.0 segundos.
- RPO observado de cero.
- Evidencia de la detención, recuperación y conservación de la última escritura confirmada.

---

## Pendientes


**E5 — Crítica**
- Comparación contra la alternativa de un nodo primario con réplica de lectura
- Conclusión sobre si la distribución estuvo justificada

**Informe**
- Actualizar el diagrama lógico: `region` ahora es parte de la PK de `pedido`
- Redactar la justificación de por qué `producto` es GLOBAL y las otras dos RBR
