# Comandos para la defensa — Proyecto 1

Todos los comandos asumen que ya se ejecutó `./scripts/setup.sh` (o su
equivalente en PowerShell) y que el clúster está corriendo. Probados en
Windows con PowerShell y Docker Desktop.

**Nota sobre el número de nodo:** el ID de nodo de CockroachDB (1, 2, 3)
cambia en cada arranque del clúster y NO corresponde siempre al mismo
contenedor (crdb-1, crdb-2, crdb-3). Antes de detener un nodo específico,
siempre verificar con `node status` cuál contenedor tiene ese ID.

---

## 0. Encender y apagar

```powershell
# Levanta el clúster completo desde cero, borrando datos previos
& "C:\Program Files\Git\bin\bash.exe" scripts/setup.sh

# Muestra el estado de los contenedores
docker compose --profile lab1 ps

# Apaga los contenedores sin borrar datos
docker compose --profile lab1 down

# Apaga y borra todo (volúmenes incluidos)
docker compose --profile lab1 down -v
```

---

## 1. Esquema y localidad de las tablas

```powershell
# Muestra la definición completa de producto (LOCALITY GLOBAL)
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SHOW CREATE TABLE producto;"

# Muestra la definición completa de stock (PK compuesta, REGIONAL BY ROW)
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SHOW CREATE TABLE stock;"

# Muestra la definición completa de pedido (PK compuesta, REGIONAL BY ROW)
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SHOW CREATE TABLE pedido;"

# Lista las regiones registradas en la base ti4601
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SHOW REGIONS FROM DATABASE ti4601;"

# Lista las regiones disponibles en todo el clúster
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 -e "SHOW REGIONS FROM CLUSTER;"

# Lista las tres tablas con su localidad y cantidad de filas
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SHOW TABLES;"
```

---

## 2. Estado del clúster y distribución de datos

```powershell
# Muestra los tres nodos, su localidad y si están disponibles
docker exec ti4601-crdb-1 cockroach node status --insecure --host=crdb-1

# Muestra en qué nodo vive el leaseholder de cada rango de producto
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SELECT range_id, lease_holder_locality, replica_localities FROM [SHOW RANGES FROM TABLE producto WITH DETAILS];"

# Lo mismo para stock
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SELECT range_id, lease_holder_locality, replica_localities FROM [SHOW RANGES FROM TABLE stock WITH DETAILS];"

# Lo mismo para pedido
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SELECT range_id, lease_holder_locality, replica_localities FROM [SHOW RANGES FROM TABLE pedido WITH DETAILS];"

# Cuenta cuántos pedidos hay por región
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SELECT region, count(*) FROM pedido GROUP BY region ORDER BY region;"

# Cuenta el total de productos
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SELECT count(*) FROM producto;"

# Cuenta cuántas filas de stock hay por región
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SELECT region, count(*) FROM stock GROUP BY region ORDER BY region;"
```

---

## 3. Evidencia guardada por setup.sh

```powershell
# Muestra el archivo con los SHOW CREATE TABLE guardados
cat evidence/show_create.txt

# Muestra el archivo con los SHOW RANGES guardados
cat evidence/show_ranges.txt

# Muestra el archivo con el conteo de pedidos por región
cat evidence/verification.txt
```

---

## 4. Mediciones de latencia (E3)

```powershell
# Corre las cuatro mediciones y guarda los resultados
& "C:\Program Files\Git\bin\bash.exe" scripts/measure_e3.sh

# Muestra la tabla de resultados (p50, p99) en formato CSV
cat evidence/e3_metrics.csv

# Lee manualmente una fila de stock en tienda-a (lectura local)
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SELECT * FROM stock WHERE region = 'tienda-a' LIMIT 1;"

# Lee manualmente una fila de stock en tienda-b (lectura remota desde crdb-1)
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601 -e "SELECT * FROM stock WHERE region = 'tienda-b' LIMIT 1;"

# Abre un prompt SQL interactivo (para correr consultas sueltas)
docker exec -it ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601
# Dentro del prompt: cualquier SELECT muestra su tiempo de ejecución.
# Para salir: escribir \q y presionar Enter.
```

---

## 5. Prueba de falla de sitio (E4)

```powershell
# Crea la base ti4601_e4 y la tabla de control con 3 réplicas votantes
Get-Content sql/e4_probe.sql | docker exec -i ti4601-crdb-1 cockroach sql --insecure --host=crdb-1

# Muestra el range_id, el leaseholder actual y los votantes de e4_probe
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601_e4 -e "SELECT range_id, lease_holder, voting_replicas FROM [SHOW RANGES FROM TABLE e4_probe WITH DETAILS];"

# Mueve el lease de ese rango al nodo indicado (usar el range_id de arriba)
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601_e4 -e "ALTER RANGE <RANGE_ID> RELOCATE LEASE TO 2;"

# Muestra qué contenedor (crdb-1, crdb-2 o crdb-3) corresponde a cada
# número de nodo; usar esto para saber cuál contenedor detener
docker exec ti4601-crdb-1 cockroach node status --insecure --host=crdb-1

# Arranca la sonda de escrituras durante 60 segundos (dejarla corriendo)
docker compose --profile lab1 run --rm --no-deps -e PGDATABASE=ti4601_e4 app-crdb python -u scripts/e4_probe.py --duration 60 --signal-file evidence/e4-stop.epoch --csv evidence/e4-chaos.csv

# En otra terminal: detiene el contenedor identificado en el paso anterior
docker compose --profile lab1 stop -t 0 crdb-X

# En esa misma terminal: guarda el instante exacto de la detención
[System.DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000 | Out-File -Encoding ascii evidence/e4-stop.epoch

# Cuando la sonda termina sola, muestra el RTO y el resumen en pantalla

# Lee la fila final para verificar el RPO
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 --database=ti4601_e4 -e "SELECT id, version, updated_at FROM e4_probe;"

# Vuelve a levantar el contenedor detenido
docker compose --profile lab1 start crdb-X

# Borra el archivo de señal temporal
Remove-Item evidence/e4-stop.epoch -ErrorAction SilentlyContinue
```

---

## 6. Evidencia guardada del E4

```powershell
# Timestamps de cuándo se detuvo el nodo
cat evidence/e4_stop.txt

# Salida completa de la sonda, incluye el RTO calculado
cat evidence/e4-probe.txt

# Verificación final de la fila (para el RPO)
cat evidence/e4-rpo.txt

# Cada intento de escritura registrado, uno por línea
cat evidence/e4-chaos.csv
```

---

## 7. Diagnóstico general

```powershell
# Lista los contenedores y su estado actual
docker compose --profile lab1 ps

# Muestra los logs de arranque de cada nodo
docker logs ti4601-crdb-1
docker logs ti4601-crdb-2
docker logs ti4601-crdb-3

# Lista todas las bases de datos del clúster
docker exec ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 -e "SHOW DATABASES;"

# Abre la interfaz web del clúster en el navegador
# http://localhost:8080
```