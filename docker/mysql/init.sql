-- MySQL Seed Data for hapo-ai-hub
-- Runs automatically on first docker compose up

CREATE DATABASE IF NOT EXISTS api_gateway
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE api_gateway;

-- Note: Tables are created by GORM auto-migrate in go-gateway.
-- This file only inserts seed data after tables exist.
-- The go-gateway service waits for MySQL health check before starting,
-- so tables will be created before this seed data is needed.

-- However, since init.sql runs BEFORE the app starts, we need a different approach:
-- The go-gateway app handles seeding via its own startup logic.
-- This file is kept as reference for manual seeding if needed.

-- For production use, seed data is managed by the go-gateway application itself.
-- See: apps/go-gateway/internal/storage/mysql/ for auto-migration and seed logic.
