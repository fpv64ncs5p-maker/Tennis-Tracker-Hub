# Tennis-Tracker-Hub

## Project Overview
Monorepo combining the Garmin tennis tracker app (MatchMind) and the Training Hub web dashboard, connected via Supabase. The goal is to keep developing both apps independently while integrating them through Supabase: the Garmin app records match data on-watch and syncs it to Supabase; the Training Hub web app reads that data and displays tennis stats alongside all other training data.

## Apps

### Training Hub (`apps/training-hub/`)
- Single-file HTML/JS/CSS web app (~7000+ lines in `index.html`)
- Deployed via GitHub Pages
- Multi-sport training dashboard: Gym · Climbing · Rehab · Planner · Tennis
- **Tennis tab LIVE (2026-06-12):** end-to-end pipeline verified — watch records match → syncs to Supabase `matches` → Tennis tab displays history, win rate, recent form, per-match stats
- Main file: `index.html`
- Live at: https://fpv64ncs5p-maker.github.io/Tennis-Tracker-Hub/

### Garmin Tennis Tracker (`apps/garmin/`)
- Monkey C app for Garmin watches (tested on Vivoactive 6)
- Branded as **MatchMind** (app files named TennisTracker)
- Tracks live tennis matches on-watch, syncs to Supabase after each match
- Key files: `source/TennisMatchEngine.mc`, `source/SupabaseSync.mc`
- Store: https://apps.garmin.com/apps/a4302e08-340f-4a11-8970-1cb44e7ab34f

## Tech Stack
- **Garmin app:** Monkey C (ConnectIQ SDK 9.1.0, API 6.0)
- **Web app:** HTML, JavaScript, CSS (single file, no build step, no external CDN)
- **Backend/Database:** Supabase — Training Hub project (`pmzzmvzbgeonjnbfreze`), `matches` table
- **Deployment:** GitHub Pages (web), ConnectIQ Store (Garmin)
- **Version control:** GitHub (private repo)

## Key Principles
- Always ask before making structural changes
- Keep this CLAUDE.md updated with important decisions
- Garmin app and web app are deployed independently
- Supabase is the bridge between both apps — Garmin writes, Training Hub reads
- Training Hub is mobile-first (700px max width), offline-first, light mode only
- MatchMind MVP principle: "I can play a full set and log every point without frustration"

## Security
- `Secrets.mc` is excluded from git (listed in `.gitignore`) — contains API keys and credentials for the Garmin app
- The GitHub repo is private
- Supabase RLS: anon INSERT (watch app) + anon SELECT (web app) + anon DELETE (web "Delete permanently"). The anon key is public — accepted trade-off for a personal tracker (`db/2026-06-16_anon_delete_matches.sql`)

## Current Version
- Garmin app: **v1.4.9** (approved + real-watch tested 2026-06-15 — tap-scoring fix confirmed working). v1.5.0 (serve/return points-played) submitted 2026-06-15, awaiting approval. v1.4.8 approved + real-watch tested 2026-06-15: Undo button works, but surfaced a tap-scoring bug (ERROR taps near the top of the button often registered as YOU/WON). v1.4.7 approved + real-watch verified 2026-06-12: sync works, rows arrive in `matches`.
- v1.4.9 (tap-scoring fix — Option 2 "buffer + bigger buttons"; `MainView.mc` only): ERROR/D.FAULT sat in a thin strip directly under the huge "tap top half = YOU won" zone with NO gap, so an ERROR tap landing a few px high silently scored for the player — made worse by v1.4.8's UNDO bar eating the bottom of the scoring band. Fix: a NEUTRAL DEAD-ZONE between WON and the buttons — a tap in `[deadZoneTopY 58%, buttonTopY 63%)` does nothing (grey blink). Buttons enlarged (now `63%→87%`, was `66%→86%`), score block nudged up (oval bottom now 58%, clears the buffer), UNDO slimmed to a 32%-wide bar. Tap zones top→bottom: WON `y<58%` · DEAD `58–63%` · ERROR/D.FAULT `63–87%` (split at centre x) · UNDO `y>87%`. iCloud build source edited; `apps/garmin/source/` mirror synced.
- v1.4.8 (4 fixes from first real-watch evening with working sync):
  1. **Supabase retry QUEUE** (5 slots, `supabase_q_0..4`, legacy key migrated) — single slot meant a failed upload was OVERWRITTEN by the next match (one match permanently lost 2026-06-12). Queue drains by chaining: each successful `onResponse` triggers `retryNextPending()`.
  2. **MatchMenu tap-twice confirm** — first tap highlights, second tap executes (RESUME pre-highlighted, so single-tap resume still works). Fixes mid-match SAVE/LATER/DISCARD mis-hits.
  3. **LATER stops + saves the recording** (`stopSessionForLater`, no sync) — previously left the session running, watch OS showed its own save dialog, matches "saved" there bypassed sync + history. One interrupted match = two Garmin activities (Jo's choice over losing HR data).
  4. **Dedicated UNDO button** (replaces MatchMind branding strip below ERROR/D.FAULT) — swipe-up undo registers as a top-half TAP on the real watch, ADDING a point instead of undoing. Swipe-up still works as fallback.
- v1.4.6: approved + installed on watch 2026-06-12. Real-watch test: activity saves to Garmin Connect but NO request reaches Supabase (confirmed via API Gateway logs). curl test with same key/payload → 201, so Supabase side is fully working; failure is on-watch and silent.
- v1.4.1: bigger fonts in MatchMenu and MatchHistory
- v1.4.2: readability improvements across Setup, MainView, MatchMenu, MatchHistory
- v1.4.3: fix Supabase sync — correct anon key in Secrets.mc; Supabase ALTER TABLE added DEFAULT 0 to stat columns, dropped NOT NULL from hr_avg/hr_max/player_served_first
- v1.4.4: remove set_scores array-of-dicts from payload — CIQ JSON serializer silently failed on nested arrays, preventing makeWebRequest from firing at all
- v1.4.5: remove hr_avg/hr_max null values + convert playerServing Boolean to 1/0 — CIQ JSON serializer silently fails on null and Boolean types
- v1.4.6: rebuild + resubmit of the v1.4.5 payload fixes. NOTE (2026-06-12 correction): the versionCode theory was wrong — the sed edit landed in the monorepo manifest (never built), the submitted .iq had NO versionCode, and the store update still reached the watch fine. versionCode is not part of the CIQ manifest schema and is irrelevant. See `MatchMind_Supabase_Sync_Findings.md`
- v1.4.7: **ROOT CAUSE FOUND & FIXED** — `"Content-Type" => "application/json"` (string) fails CIQ's local header validation with -200 (INVALID_HTTP_HEADER_FIELDS_IN_REQUEST); the request NEVER left the watch, on simulator and real device alike, in every version since sync was built. Fix: `"Content-Type" => Comm.REQUEST_CONTENT_TYPE_JSON` (enum constant). Verified in simulator: SYNC OK + rows inserted in `matches` (incl. retried stuck payload). Also in v1.4.7: visible sync status (new `SyncStatus.mc`) in PostMatchView + SetupView — `SYNC ...` / `SYNC SENT` / `SYNC OK` (green) / `SYNC ERR n` (red) / `SYNC EXC`; and Prefer header → `return=representation` (empty 201 body from `return=minimal` triggers CIQ -400 with JSON responseType, disguising success as failure)

## Deployment

### Training Hub (web app)
- Edit `index.html` in `apps/training-hub/`
- Copy changes to root: `cp apps/training-hub/index.html .` (the root file is what GitHub Pages serves)
- **Deploy via GitHub Desktop** (replaces the old `curl`/GitHub-API push): open GitHub Desktop → review the diff → type a summary → **Commit to main** → **Push origin**. GitHub Pages auto-deploys in ~1 min. Desktop handles auth, so no token needed.
- GitHub Desktop and Claude both work in the **same** folder (`~/Documents/Tennis-Tracker-Hub`) — single source of truth, no duplicate clones.
- Day-to-day cheat-sheet: see `GIT_WORKFLOW.md` (repo root).
- Live at: https://fpv64ncs5p-maker.github.io/Tennis-Tracker-Hub/

### Garmin App
- ⚠️ **The build source of truth is the iCloud folder** (`PROJ007_Garmin App/Tennistracker/`) — `package.sh`/`run.sh` build THERE. `apps/garmin/` in this repo is a mirror for version control. Always edit the iCloud copy (or edit both), then keep them in sync — on 2026-06-12 a fix applied only to the mirror never made it into the built `.iq`.
- Source code in `apps/garmin/source/`
- `Secrets.mc` is NOT in git (excluded via .gitignore) — kept locally only
- Build for simulator: `./run.sh` (from iCloud project folder)
- Build for store:
  ```bash
  cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/01\ Claude\ in\ Docs/02\ Projects/PROJ007_Garmin\ App/Tennistracker
  ./package.sh
  ```
  → generates `bin/Tennistracker.iq`
- Submit `.iq` file to: https://developer.garmin.com/connect-iq/sdk/
- Garmin approval takes ~2 hours
- Users install update from ConnectIQ Store

## Supabase Integration
- Project ID: `pmzzmvzbgeonjnbfreze`
- Table: `matches` (29 columns: all engine stats incl. serve/return points played+won, + nullable opponent_name, location, notes)
- RLS: anon INSERT (watch) + anon SELECT (web) + anon DELETE (web permanent-delete, `db/2026-06-16_anon_delete_matches.sql`)
- Watch app credentials in `Secrets.mc` (gitignored)

## Training Hub — Key Context
- **Architecture:** single-file, localStorage-first, no build step
- **Sync:** Supabase `user_data` table (migrated from GitHub Gist 2026-05-27 — DNS issue no longer present, Supabase confirmed working on mobile)
- **Tennis integration:** Tennis tab reads `matches` from Supabase (REST + anon key) and merges them with manually-logged matches (`tennis_matches` in localStorage).
- **Watch-match editing (overlay):** watch rows are not editable in the DB (no anon UPDATE). Web-side enrichment — Competition/Training category, partner, opponent, location, notes — and "remove from tab" (soft-hide, reversible) live in a `tennis_overlay` localStorage object keyed by match id, synced across devices via `user_data`. Two removal modes: "remove from tab" = reversible soft-hide (overlay only, no DB change); "Delete permanently" removes the row via an anon DELETE policy (`db/2026-06-16_anon_delete_matches.sql`). Doubles get a 2nd opponent field (Partner + Opponent 2 shown only for doubles). (Live + confirmed by Jo 2026-06-15.)
- **Serve/return %:** needs `service_points_played` + `return_points_played` columns (`db/2026-06-15_add_serve_return_played.sql`) + MatchMind **v1.5.0** to send them (engine already counts them; web already reads them, NULL-tolerant). v1.4.9 approved 2026-06-15; v1.5.0 submitted 2026-06-15, awaiting approval. **SQL columns added 2026-06-15 (confirmed by Jo, before submission)** — once v1.5.0 is approved + installed, serve/return won-lost + win% populate for new matches.
- **Activity colours:** Tennis = `#a78bfa` (lavender)
- **Tabs:** Home · Gym · Climbing · Rehab · Planner · (Tennis — to be added/integrated)

## Reference Folders
- `apps/garmin/V.1 POJ007_Garmin App files/` — V1 Garmin project files, decisions log, architecture docs
- `apps/training-hub/V1 training-hub files/` — V1 Training Hub project files, full decisions log, specs
