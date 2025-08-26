-- 000_points_ledger_keys.sql
-- Add unique constraints and performance indexes to points_ledger
-- Safe to re-run (idempotent)

-- First, clean up any duplicate points records (keep the earliest one)
DELETE p1 FROM points_ledger p1
INNER JOIN points_ledger p2 
WHERE p1.id > p2.id 
  AND p1.memberid = p2.memberid 
  AND p1.saleid = p2.saleid 
  AND p1.source_code = p2.source_code 
  AND p1.points = p2.points;

-- Add unique key to prevent duplicates during backfill
-- This ensures one points record per (member, sale, source, amount) combination
ALTER TABLE points_ledger
  ADD UNIQUE KEY uq_points_nodup (memberid, saleid, source_code, points);

-- Performance indexes for common query patterns
-- Member + phase queries (wallet balance by phase)
CREATE INDEX idx_pl_member_phase_created ON points_ledger(memberid, phase, created_at);

-- Source code queries (reporting by commission type)  
CREATE INDEX idx_pl_source_created ON points_ledger(source_code, created_at);

-- Currency-based queries (USD/INR reporting)
CREATE INDEX idx_pl_currency_created ON points_ledger(currency, created_at);

-- Note-based queries (backfill vs real-time tracking)
CREATE INDEX idx_pl_note ON points_ledger(note(50));
