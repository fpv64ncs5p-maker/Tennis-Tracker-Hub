// ============================================================
// Secrets.mc — credentials kept out of source control
// MatchMind Tennis Tracker for Garmin Vivoactive 6
// ============================================================
// Holds the Supabase project URL and anon API key used by
// SupabaseSync to POST match results to the Training Hub
// `matches` table.
//
// Why a separate file: source-control hygiene. Add this file
// to .gitignore so the anon key never ends up in a public repo.
// Note: the key is still compiled into the .iq binary — see
// SupabaseSync.mc for details. RLS on the matches table is what
// actually restricts what the key can do (insert only into the
// matches table for the anon role).
// ============================================================

module Secrets {

    // v1.3.1: switched from Golf-tracker project to Training Hub project
    // so all MatchMind data lives alongside the rest of Training Hub.
    const SUPABASE_URL = "https://pmzzmvzbgeonjnbfreze.supabase.co";

    const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBtenptdnpiZ2VvbmpuYmZyZXplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2Nzk1ODUsImV4cCI6MjA5MjI1NTU4NX0.4yydLRsigkbKjCb0VCPt9-ppxtPUPWbs5c6y-4C8szk";
}
