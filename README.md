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

---

## Cómo levantar el proyecto

Requiere Docker y Docker Compose instalados.

**1. Levantar el clúster**

```bash
docker compose --profile lab1 up -d
```

**2. Crear la base de datos**

```bash
docker exec -it ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 \
  -e "CREATE DATABASE IF NOT EXISTS ti4601;"
```

**3. Configurar las regiones**

```bash
docker exec -i ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 \
  --database=ti4601 < sql/regions.sql
```

**4. Crear las tablas**

```bash
docker exec -i ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 \
  --database=ti4601 < sql/schema.sql
```

**5. Cargar los datos**

```bash
docker cp sql/seed.sql ti4601-crdb-1:/tmp/seed.sql
docker exec -it ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 \
  --database=ti4601 -f /tmp/seed.sql
```

**6. Verificar**

```bash
docker exec -it ti4601-crdb-1 cockroach sql --insecure --host=crdb-1 \
  --database=ti4601 -e "SELECT region, count(*) FROM pedido GROUP BY region;"
```

Debe mostrar 100 pedidos por región.

**Para apagar todo:**

```bash
docker compose --profile lab1 down
```

---

## Estado actual

Funciona:

- Clúster de tres nodos con las regiones del dominio
- Las tres tablas creadas con sus localidades
- Datos cargados y distribuidos correctamente por región
- `SHOW RANGES` confirma que cada región tiene su leaseholder en su propio nodo

Nota sobre subreplicación: los rangos REGIONAL BY ROW aparecen con dos réplicas
en lugar de tres. Es comportamiento esperado en un clúster con un solo nodo por
región, documentado en el laboratorio 1 del curso. No impide el funcionamiento.

---

## Pendientes

**E2 — Implementación**
- Script reproducible de configuración que automatice los pasos 2 a 5
- Recolectar evidencia formal de `SHOW RANGES` y `SHOW CREATE TABLE` en `evidence/`

**E3 — Mediciones**
- Script de medición de latencia sobre las operaciones del dominio
- 30 corridas mínimo por cada caso: lectura local, lectura remota, escritura local, escritura que cruza región
- Tabla con p50, p99 y metodología documentada

**E4 — Falla de sitio**
- Crear una tabla de control con RF=3 real, necesaria porque los rangos RBR están subreplicados
- Script que orqueste la caída de un nodo
- Bitácora con timestamps, RTO observado y discusión de RPO

**E5 — Crítica**
- Comparación contra la alternativa de un nodo primario con réplica de lectura
- Conclusión sobre si la distribución estuvo justificada

**Informe**
- Actualizar el diagrama lógico: `region` ahora es parte de la PK de `pedido`
- Redactar la justificación de por qué `producto` es GLOBAL y las otras dos RBR
