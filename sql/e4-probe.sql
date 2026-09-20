-- Project 1 — TI-4601 Advanced Databases

-- E4 control table: node failure test

-- Create an independent database for the failure test.

CREATE DATABASE IF NOT EXISTS ti4601_e4;

-- Control table used to perform confirmed writes during the test.The version column increases after every successful write.

CREATE TABLE IF NOT EXISTS ti4601_e4.public.e4_probe (
    id INT8 PRIMARY KEY,
    version INT8 NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Store three voting replicas, one on each available CockroachDB node, this allows the table to remain available after one node is stopped.

ALTER TABLE ti4601_e4.public.e4_probe
CONFIGURE ZONE USING
    num_replicas = 3,
    num_voters = 3;

-- Create the initial control row.
-- ON CONFLICT prevents duplicating it when the script is executed again.

INSERT INTO ti4601_e4.public.e4_probe (
    id,
    version,
    updated_at
)
VALUES (
    1,
    0,
    now()
)
ON CONFLICT (id) DO NOTHING;