-- Project 1 — TI-4601 Advanced Databases

-- E4 control table: node failure test

-- Create an independent database for the failure test.



CREATE DATABASE IF NOT EXISTS ti4601_e4;

-- The version increments with each committed write.
CREATE TABLE IF NOT EXISTS ti4601_e4.public.e4_probe (
    id INT8 PRIMARY KEY,
    version INT8 NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Three replicas are required to respond.
ALTER TABLE ti4601_e4.public.e4_probe
CONFIGURE ZONE USING
    num_replicas = 3,
    num_voters = 3;

-- The row is not reset if the file is re-run.
INSERT INTO ti4601_e4.public.e4_probe (id, version)
VALUES (1, 0)
ON CONFLICT (id) DO NOTHING;

-- Verification of replicas and the node holding the lease.
SELECT range_id, lease_holder, voting_replicas,
       replica_localities
FROM [SHOW RANGES FROM TABLE
      ti4601_e4.public.e4_probe WITH DETAILS];