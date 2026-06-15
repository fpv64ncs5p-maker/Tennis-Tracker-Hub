-- Migration: add serve/return points-played columns to `matches`
-- Date: 2026-06-15
-- Purpose: enables full serve/return won–lost + win% in the Training Hub Tennis tab.
--   The watch already counts these; MatchMind v1.5.0+ will start sending them.
--   Existing rows stay NULL (older matches can't be backfilled).
-- Safe to run anytime: the web app already reads these columns and tolerates NULL.
-- Run in: Supabase dashboard → SQL editor (Training Hub project pmzzmvzbgeonjnbfreze)

alter table public.matches
  add column if not exists service_points_played integer,
  add column if not exists return_points_played  integer;
