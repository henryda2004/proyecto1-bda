-- Project 1 — TI-4601 Advanced Databases
-- Schema: Multi-store commerce inventory
-- Engine: CockroachDB v24.3.0

-- Global table: replicated across all regions for local reads
CREATE TABLE IF NOT EXISTS producto (
    codProducto UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre STRING NOT NULL,
    precio DECIMAL(12, 2) NOT NULL CHECK (precio >= 0)
) LOCALITY GLOBAL;

-- Sharded by region: each store owns its inventory rows
CREATE TABLE IF NOT EXISTS stock (
    region crdb_internal_region NOT NULL,
    codProducto UUID NOT NULL REFERENCES producto (codProducto),
    unidades INT8 NOT NULL CHECK (unidades >= 0),
    PRIMARY KEY (region, codProducto)
) LOCALITY REGIONAL BY ROW AS region;

-- Sharded by region: orders belong to the store that placed them
CREATE TABLE IF NOT EXISTS pedido (
    region crdb_internal_region NOT NULL,
    codPedido UUID NOT NULL DEFAULT gen_random_uuid(),
    codProducto UUID NOT NULL REFERENCES producto (codProducto),
    codCliente STRING NOT NULL,
    unidades INT8 NOT NULL CHECK (unidades > 0),
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (region, codPedido)
) LOCALITY REGIONAL BY ROW AS region;