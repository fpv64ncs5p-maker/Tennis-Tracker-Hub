# Tennis-Tracker-Hub

## Project Overview
Monorepo combining the Garmin tennis tracker app (MatchMind) and the Training Hub web dashboard, connected via Supabase. The goal is to keep developing both apps independently while integrating them through Supabase: the Garmin app records match data on-watch and syncs it to Supabase; the Training Hub web app reads that data and displays tennis stats alongside all other training data.

## Apps

### Training Hub (`apps/training-hub/`)
- Single-file HTML/JS/CSS web app (~7000+ lines in `index.html`)
- Deployed via GitHub Pages
- Multi-sport training dashboard: Gym · Climbing · Rehab · Planner · Tennis
- **Current integration goal:** add a Tennis tab that reads match stats from Supabase
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
- Supabase RLS: anon INSERT (watch app) + anon SELECT (web app)

## Current Version
- Garmin app: **v1.3.8** (ready to build & submit — Supabase retry now uses dedicated payload key, survives clearState())

## Deployment

### Training Hub (web app)
- Edit `index.html` in `apps/training-hub/`
- Copy changes to root: `cp apps/training-hub/index.html .`
- Commit and push to GitHub → auto-deploys via GitHub Pages
- Live at: https://fpv64ncs5p-maker.github.io/Tennis-Tracker-Hub/

### Garmin App
- Source code in `apps/garmin/source/`
- `Secrets.mc` is NOT in git (excluded via .gitignore) — kept locally only
- Build for simulator: `./run.sh` (from iCloud project folder)
- Build for store: `./package.sh` → generates `bin/Tennistracker.iq`
- Submit `.iq` file to: https://developer.garmin.com/connect-iq/sdk/
- Garmin approval takes ~2 hours
- Users install update from ConnectIQ Store

## Supabase Integration
- Project ID: `pmzzmvzbgeonjnbfreze`
- Table: `matches` (27 columns: all engine stats + nullable opponent_name, location, notes)
- RLS: anon INSERT (watch) + anon SELECT (web)
- Watch app credentials in `Secrets.mc` (gitignored)

## Training Hub — Key Context
- **Architecture:** single-file, localStorage-first, no build step
- **Sync:** Supabase `user_data` table (migrated from GitHub Gist 2026-05-27 — DNS issue no longer present, Supabase confirmed working on mobile)
- **Tennis integration:** will use Supabase JS SDK to read `matches` table (separate from localStorage data)
- **Activity colours:** Tennis = `#a78bfa` (lavender)
- **Tabs:** Home · Gym · Climbing · Rehab · Planner · (Tennis — to be added/integrated)

## Reference Folders
- `apps/garmin/V.1 POJ007_Garmin App files/` — V1 Garmin project files, decisions log, architecture docs
- `apps/training-hub/V1 training-hub files/` — V1 Training Hub project files, full decisions log, specs
