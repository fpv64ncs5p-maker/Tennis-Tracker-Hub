-- ══════════════════════════════════════════════════════════════
-- Training Hub — Supabase user_data table
-- Run this in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/pmzzmvzbgeonjnbfreze/sql
-- ══════════════════════════════════════════════════════════════

-- Drop table if you're re-running this script
-- DROP TABLE IF EXISTS user_data;

CREATE TABLE IF NOT EXISTS user_data (
  id             TEXT    PRIMARY KEY,
  data           JSONB   NOT NULL DEFAULT '{}',
  last_modified  BIGINT  NOT NULL DEFAULT 0
);

-- Enable Row Level Security
ALTER TABLE user_data ENABLE ROW LEVEL SECURITY;

-- Allow anonymous reads (so any device can pull data)
CREATE POLICY "anon_select"
  ON user_data FOR SELECT
  USING (true);

-- Allow anonymous inserts (first-time push)
CREATE POLICY "anon_insert"
  ON user_data FOR INSERT
  WITH CHECK (true);

-- Allow anonymous updates (subsequent pushes)
CREATE POLICY "anon_update"
  ON user_data FOR UPDATE
  USING (true);

-- ══════════════════════════════════════════════════════════════
-- That's it! After running this, open the Training Hub app,
-- restore your JSON backup via "Restore Backup", then click
-- "Push to Cloud" to seed Supabase with your historical data.
-- ══════════════════════════════════════════════════════════════
