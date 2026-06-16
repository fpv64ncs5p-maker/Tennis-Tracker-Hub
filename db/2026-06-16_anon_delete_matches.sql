-- Migration: allow the web app (anon) to permanently delete match rows
-- Date: 2026-06-16
-- Enables the Tennis tab "Delete permanently from database" action.
--
-- Trade-off (accepted by Jo): the anon key is public (embedded in the
-- GitHub Pages site), so this lets anyone holding that key delete rows in
-- `matches`. Acceptable for a private, non-sensitive personal tracker.
-- To revert: drop policy "anon delete matches" on public.matches;
--
-- Run in: Supabase dashboard -> SQL editor (Training Hub project pmzzmvzbgeonjnbfreze)

create policy "anon delete matches"
  on public.matches
  for delete
  to anon
  using (true);
