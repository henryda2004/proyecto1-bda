-- Project 1 — TI-4601 Advanced Databases
-- Multi-region configuration
-- Run before schema.sql

-- Enable multi-region on the database.
-- Region names must match the --locality flags in docker-compose.yml
ALTER DATABASE ti4601 PRIMARY REGION "tienda-a";
ALTER DATABASE ti4601 ADD REGION IF NOT EXISTS "tienda-b";
ALTER DATABASE ti4601 ADD REGION IF NOT EXISTS "cd-central";

-- Survive a single node failure
ALTER DATABASE ti4601 SURVIVE ZONE FAILURE;