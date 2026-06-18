# Git Workflow — Tennis-Tracker-Hub (with GitHub Desktop)

> One-page cheat-sheet for day-to-day work. Plain language, no jargon.
> **Last updated:** 2026-06-18

---

## The setup (why this is clean)

- **One folder is the single source of truth:** `~/Documents/Tennis-Tracker-Hub`
- That same folder is (a) where Claude edits files, (b) what GitHub Desktop tracks, and (c) what deploys to your live site.
- **Don't clone the repo again.** If you ever see a `~/Documents/GitHub/Tennis-Tracker-Hub`, that's a stray duplicate — delete it.

## The only 4 words you need

- **Commit** — save a labeled snapshot of your changes, on your computer.
- **Push** — send your commits up to GitHub. For the web app, this triggers the live site to rebuild.
- **Pull** — bring commits down from GitHub into your folder.
- **Fetch** — just check GitHub for new commits (no download). GitHub Desktop does this for you automatically.

## Deploy a Training Hub (web app) change

1. Claude edits `index.html` and copies it to the repo root (the root file is what GitHub Pages serves).
2. Open **GitHub Desktop** → review the highlighted changes (green = added, red = removed).
3. Bottom-left: type a short summary → click **Commit to main**.
4. Top bar: click **Push origin**.
5. ~1 minute later the live site updates: https://fpv64ncs5p-maker.github.io/Tennis-Tracker-Hub/

That's the whole deploy — no token, no `curl`, no base64.

## Daily habit

- **Start of a session:** in Desktop, click **Fetch origin**, then **Pull** if it shows incoming changes (catches anything Claude pushed).
- **End of a session:** Commit + Push, so nothing is left only on your computer.

## Good commit messages (short + specific)

- ✅ "Tennis: fix win-rate calc for doubles"
- ✅ "Planner: add weekly streak indicator"
- ❌ "update" · "stuff" · "changes"

## The Garmin app is different — do NOT deploy it through Desktop

- The watch app **builds from the iCloud folder** (`PROJ007_Garmin App/Tennistracker/`), not from this repo.
- `apps/garmin/` here is just a **version-controlled mirror** (backup + history). Committing it to GitHub does NOT build or submit the watch app.
- To ship a watch update you still: build the `.iq` in iCloud (`./package.sh`) → submit it at the Garmin developer site.

## If something looks scary

- **"You have changes you haven't committed"** — normal. It just means edits aren't snapshotted yet. Commit them (or discard if you didn't want them).
- **A push is rejected / "your branch is behind"** — Desktop will offer **Pull** first. Pull, then Push.
- **Merge conflict** (rare on a single machine) — stop and ask Claude; don't guess.
- **Never** click "Discard all changes" unless you truly want to throw away uncommitted work.

---
_Keep this current whenever the workflow changes._
