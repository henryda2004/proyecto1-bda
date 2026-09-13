-- Project 1 — TI-4601 Advanced Databases
-- Seed data: multi-store commerce inventory
-- Run after schema.sql

-- Fixed seed for reproducible pseudo-random data
SELECT setseed(0.42);

-- Product catalog (global table, replicated in all regions)
INSERT INTO producto (nombre, precio) VALUES
    ('Arroz 1kg', 1200.00),
    ('Frijoles negros 900g', 1450.00),
    ('Aceite vegetal 1L', 2300.00),
    ('Azucar 2kg', 1850.00),
    ('Cafe molido 500g', 3900.00),
    ('Leche entera 1L', 1100.00),
    ('Pan cuadrado 600g', 1650.00),
    ('Huevos 30 unidades', 4200.00),
    ('Atun en lata 140g', 1350.00),
    ('Pasta espagueti 500g', 980.00);

-- Stock: every product in every region (sharded by region)
INSERT INTO stock (region, codProducto, unidades)
SELECT
    r.region,
    p.codProducto,
    (random() * 100)::INT8 + 10
FROM producto p
CROSS JOIN (
    VALUES
        ('tienda-a'::crdb_internal_region),
        ('tienda-b'::crdb_internal_region),
        ('cd-central'::crdb_internal_region)
) AS r(region);

-- Orders: 100 per region (sharded by region)
INSERT INTO pedido (region, codProducto, codCliente, unidades, fecha)
SELECT
    r.region,
    (SELECT codProducto FROM producto ORDER BY random() LIMIT 1),
    'CLI-' || LPAD(g::STRING, 4, '0'),
    (random() * 5)::INT8 + 1,
    now() - (random() * 30)::INT * INTERVAL '1 day'
FROM generate_series(1, 100) AS g
CROSS JOIN (
    VALUES
        ('tienda-a'::crdb_internal_region),
        ('tienda-b'::crdb_internal_region),
        ('cd-central'::crdb_internal_region)
) AS r(region);