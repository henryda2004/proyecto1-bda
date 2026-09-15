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
3. Configura las regiones de la base de datos.
4. Crea las tablas del esquema.
5. Carga los datos de prueba.
6. Verifica la cantidad de pedidos por región.
7. Genera automáticamente la evidencia de E2.

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

---

## Pendientes
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
