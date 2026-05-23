# Tennis-Tracker-Hub

## Project Overview
Monorepo combining the Garmin tennis tracker app and the Training Hub web dashboard, connected via Supabase.

## Structure
## Apps

### Training Hub (`apps/training-hub/`)
- Static HTML/JS web app
- Deployed via GitHub Pages
- Displays tennis match stats stored in Supabase
- Main file: `index.html`

### Garmin Tennis Tracker (`apps/garmin/`)
- Monkey C app for Garmin watches (tested on Vivoactive 6)
- Tracks live tennis matches on the watch
- Syncs match data to Supabase after each match
- Key files: `source/TennisMatchEngine.mc`, `source/SupabaseSync.mc`

## Tech Stack
- **Garmin app:** Monkey C (ConnectIQ SDK)
- **Web app:** HTML, JavaScript, CSS
- **Backend/Database:** Supabase
- **Deployment:** GitHub Pages (web), ConnectIQ Store (Garmin)
- **Version control:** GitHub

## Key Principles
- Always ask before making structural changes
- Keep this CLAUDE.md updated with important decisions
- Garmin app and web app are deployed independently
- Supabase is the bridge between both apps
