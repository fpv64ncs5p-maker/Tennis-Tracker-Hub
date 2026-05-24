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

## Security
- `Secrets.mc` is excluded from git (listed in `.gitignore`) — contains API keys and credentials for the Garmin app
- The GitHub repo is private

## Deployment

### Training Hub (web app)
- Edit `index.html` in root or `apps/training-hub/`
- Copy changes to root: `cp apps/training-hub/index.html .`
- Commit and push to GitHub → auto-deploys via GitHub Pages
- Live at: https://fpv64ncs5p-maker.github.io/Tennis-Tracker-Hub/

### Garmin App
- Source code in `apps/garmin/source/`
- `Secrets.mc` is NOT in git (excluded via .gitignore) — kept locally only
- Build for simulator: `./run.sh`
- Build for store: `./package.sh` → generates `bin/Tennistracker.iq`
- Submit `.iq` file to: https://developer.garmin.com/connect-iq/sdk/
- Garmin approval takes ~2 hours
- Users install update from ConnectIQ Store
