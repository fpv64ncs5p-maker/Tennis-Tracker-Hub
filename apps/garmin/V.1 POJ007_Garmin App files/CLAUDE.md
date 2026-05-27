# CLAUDE.md — MatchMind Garmin App
*Last updated: 2026-05-22*

---

## Project Identity

| Field | Value |
|---|---|
| App name (branding) | **MatchMind** |
| App name (manifest/files) | TennisTracker |
| Company | MatchMind Studio |
| Device | Garmin Vívoactive 6 (390×390px, round AMOLED) |
| Language | Monkey C |
| SDK | Connect IQ 9.1.0 |
| API Level | 6.0 |
| App ID (public) | `a4302e08-340f-4a11-8970-1cb44e7ab34f` |
| Store URL | https://apps.garmin.com/apps/a4302e08-340f-4a11-8970-1cb44e7ab34f |
| Dev contact email | sportsmanagementjb+matchmind@gmail.com |
| Project path | iCloud → 01 Claude in Docs → 02 Projects → PROJ007_Garmin App → Tennistracker |

---

## About Jo (the developer)

- Complete beginner to app development — explain steps clearly and patiently
- Designs for real use: tired, mid-match, one hand
- Prefers brief and to-the-point explanations
- Always ask before making non-obvious decisions
- Always maintain this file and the DECISIONS LOG with important changes

---

## Tech Stack

- **Language:** Monkey C (Connect IQ 9.1.0, API 6.0)
- **Input:** `Ui.InputDelegate` (TouchDelegate was removed in API 6.0)
- **Activity recording:** `Toybox.ActivityRecording` + `Toybox.FitContributor`
- **Persistence:** `Toybox.Storage` (flat String-keyed dict, primitives only — Symbol keys and nested dicts crash CIQ Storage)
- **Backend:** Supabase — Training Hub project (`pmzzmvzbgeonjnbfreze`), `matches` table, RLS with anon INSERT/SELECT
- **Build tool:** `monkeyc` CLI (SDK at `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin/`)
- **Java:** Temurin via Homebrew (java.com installer is incompatible with Apple Silicon)

---

## Source Files

| File | Purpose |
|---|---|
| `App.mc` | Entry point — `getInitialView()` only (using both `onStart` + `getInitialView` causes double-push crash) |
| `SetupView.mc` | Pre-match config: TYPE (Singles/Doubles), FORMAT preset, SERVES 1ST, HISTORY row, START button |
| `MainView.mc` | Match screen + ConfirmEndView (end match confirmation overlay) |
| `TennisMatchEngine.mc` | Core scoring logic: points, games, sets, tiebreak, super tiebreak, undo, all stats |
| `TennisActivityManager.mc` | ActivityRecording session (SPORT_TENNIS / SUB_SPORT_MATCH), HR sensor, FIT fields, Supabase trigger |
| `PostMatchView.mc` | Post-match summary — page 1: match stats; page 2: health stats |
| `MatchPersistence.mc` | Save/resume match state via Toybox.Storage |
| `MatchHistory.mc` | Stores last 5 completed matches in Toybox.Storage |
| `MatchHistoryView.mc` | Browse match history on-watch (swipe left/right, delete with confirmation) |
| `MatchMenu.mc` | Garmin-style end-match menu: RESUME / SAVE / LATER / DISCARD |
| `Secrets.mc` | SUPABASE_URL + anon key — **gitignored, not in repo** |
| `SupabaseSync.mc` | POSTs match JSON to Supabase `/rest/v1/matches` at end of session |

---

## Build Commands

**Simulator (easy — use `run.sh`):**
```bash
cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/01\ Claude\ in\ Docs/02\ Projects/PROJ007_Garmin\ App/Tennistracker
./run.sh
```

**Manual simulator build:**
```bash
~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin/monkeyc \
  -o bin/Tennistracker.prg -f monkey.jungle -y developer_key -d vivoactive6_sim -w
```

**Store package (.iq) — use `-e` flag NOT `-r`:**
```bash
"$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin/monkeyc" \
  -o bin/Tennistracker.iq -f monkey.jungle -y developer_key -e -w
```

> ⚠️ `-r` (release) produces a `.iq` that Garmin rejects with "error processing manifest file". Always use `-e` (export) for store submissions. `package.sh` is already updated.

**Run in simulator:**
```bash
~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin/monkeydo \
  bin/Tennistracker.prg vivoactive6
```

---

## Key Technical Decisions & Gotchas

| Decision | Choice | Why |
|---|---|---|
| Input delegate | `Ui.InputDelegate` | `TouchDelegate` removed in API 6.0 |
| Entry point | `getInitialView()` only | `onStart()` + `getInitialView()` causes double-push crash |
| View casting | `Ui.getCurrentView()[0] as ViewName` in API 6.0 — BUT on real watch, use view-by-reference pattern | `getCurrentView()` return type differs sim vs real watch in SDK 9.x |
| `drawRoundedRectangle` | Not used | Doesn't exist in API 6.0 — use `fillRoundedRectangle` or `drawRectangle` |
| Physical button key | `onKey()` catches all keys | Avoids hardcoding key constants that differ by device |
| Storage serialization | Flat String-keyed dict, primitives only | CIQ Storage crashes on Symbol keys (`:name`) and nested dicts |
| setHistory in Storage | Two parallel Number arrays `"shP"` / `"shO"` | Cannot store array of Symbol-keyed dicts |
| Sport type | `SPORT_TENNIS / SUB_SPORT_MATCH` | SPORT_GENERIC was tested (v1.1.7–1.1.8) but Garmin filters dev fields universally — switching sport type gains nothing; keep Tennis for racket icon + aggregation |
| FIT developer fields | Seeded with `setData(0)` before `_session.start()` | Without initial seed, Garmin Connect strips the Connect IQ section entirely |
| Garmin Connect stats | Human-readable field names (e.g. "Points won") | Short codes (`p_pts`) are filtered server-side by Garmin's Tennis template |
| Lap announcements | Removed `_session.addLap()` from `markSetEnd()` | Garmin OS announces laps out loud (beep + vibration) — disruptive mid-match |
| Vivoactive 6 USB | No mass storage mode | Newer Garmin devices dropped USB drive mode — install via Connect IQ Store only |
| App distribution | Public (not beta) | Beta apps never enter the review queue; dev/user accounts are different — beta can't reach Jo's watch |
| `manifest.xml` type | `type="watch-app"` | `type="activity"` does not exist in CIQ SDK — causes build error |
| Supabase project | Training Hub (`pmzzmvzbgeonjnbfreze`) | Tennis data was already flowing there; consolidates all training data |

---

## Architecture (5 Modules)

1. **TennisMatchEngine** — scoring logic (points → games → sets), deuce, tiebreak, super tiebreak, undo, serve tracking, stats
2. **Input Handler** — WON / ERROR / DOUBLE FAULT inputs via InputDelegate
3. **History Manager (Undo)** — stack-based state snapshots (max 50), full state restored
4. **Activity Manager** — HR sensor, ActivityRecording session, FIT fields, Supabase sync
5. **UI Layer** — SetupView, MainView, MatchMenu, PostMatchView, MatchHistoryView, ConfirmEndView, ResumePromptView

---

## Main Match Screen Layout

```
┌──────────────────────────────┐
│   HR:115        22:30        │  ← status bar (HR left, clock right)
│          00:18               │  ← match timer (center)
├──────────────────────────────┤
│  YOU   GAMES    OPP          │  ← player labels + "GAMES" label
│        1-5                   │  ← current game score (center)
│        6-0                   │  ← set history (gray, center)
│  [●]           40            │  ← serving dot (yellow) + big points (FONT_NUMBER_MILD)
├──────────────────────────────┤
│  [ ERROR ]    [ D.FAULT ]    │  ← red outline buttons
├──────────────────────────────┤
│          MatchMind           │  ← branding
└──────────────────────────────┘
```

**Touch interactions:**
- Tap top half → YOU won the point (green flash)
- Tap ERROR → opponent won, unforced error (red flash)
- Tap D.FAULT → opponent won, double fault (orange flash)
- Swipe UP → undo last point (blue flash)
- Physical button → MatchMenu (RESUME / SAVE / LATER / DISCARD)

**Key layout constants:**
- `STATUS_DIVIDER_Y = 78`, `BUTTON_Y = 252`, `BUTTON_BOTTOM_Y = 302`
- `P1_X = 90`, `P2_X = 300`, `CENTER_X = 195`
- Button inset = 78 (keeps buttons inside round screen bounds)

---

## Scoring Logic

- Points: 0 → 15 → 30 → 40 → Deuce → Advantage → Game
- Tiebreak at 6-6 (first to 7, lead by 2)
- Super tiebreak for final set (first to 10, lead by 2) — starts at beginning of deciding set via `enterSuperTBIfFinalSet()`
- Server rotates: after every game; in tiebreaks: 1 point then every 2
- Input types: WON (0), ERROR (1), DOUBLE_FAULT (2)
- `needsChangeover` flag: set after odd game totals / every 6 tiebreak points → yellow "SWITCH ENDS" banner in MainView

---

## Match Formats (SetupView presets)

| Preset | Config | Notes |
|---|---|---|
| 1 Set | 1 set to win, tiebreak ON, no super TB | Quick match |
| Best of 3 (Singles) | 2 sets to win, tiebreak ON, no super TB | Standard singles |
| Best of 3+ST (Doubles) | 2 sets to win, tiebreak ON, super TB decider ON | Standard doubles |
| Super TB | Single 10-point super tiebreak | Fast decider |

Switching TYPE (Singles/Doubles) resets formatPreset to 0.

---

## Stats Tracked

| Stat | Description |
|---|---|
| winners | Points won (WON inputs) |
| unforcedErrors | Points lost via ERROR |
| doubleFaults | Points lost via DOUBLE_FAULT |
| servePtsPlayed / Won | Points while serving |
| returnPtsPlayed / Won | Points while returning |
| setWinners / setErrors / setDF | Per-set counters (reset each set) |
| tiebreakPointsWon/Lost / tiebreaksWon | Match-level tiebreak stats |

FIT fields written at match end (SESSION) and per set (LAP).

---

## Navigation / Exit Flow

```
Mid-match → physical button
    ↓
MatchMenu: RESUME / SAVE / LATER / DISCARD
    RESUME → back to match
    SAVE   → PostMatchView → BACK → SetupView (3× popView)
    LATER  → exit app, state saved (resume on next launch)
    DISCARD → DiscardConfirmView → YES: drop activity → SetupView

PostMatchView → BACK = 3 consecutive popView calls (unwinds full stack)
```

---

## Match History (on-watch)

- Stores last 5 completed matches in `Toybox.Storage`
- Keys: `won`, `setsP/O`, `sets`, `ptsW/L`, `err`, `df`, `date` (unix timestamp), `mtype`
- `MatchHistoryView`: swipe LEFT = older, RIGHT = newer; DELETE button with YES/NO inline confirmation
- Accessible from SetupView as 4th navigable row (swipe to reach)

---

## Supabase Integration

- Project: Training Hub (`pmzzmvzbgeonjnbfreze`)
- Table: `matches` (27 columns: all engine stats + nullable `opponent_name`, `location`, `notes`)
- RLS: anon INSERT (watch app) + anon SELECT (web app)
- Credentials: in `Secrets.mc` (gitignored)
- Sync: called at end of `stopSession()` in `TennisActivityManager`; discarded matches skip sync

---

## Version History (summary)

| Version | Key change |
|---|---|
| v1.0 | Initial build |
| v1.1.0 | FitContributor + ActivityRecording; launcher icon; store submission |
| v1.1.1 | Public store submission; new appID; tap bug fixes — **APPROVED 2026-05-06** |
| v1.1.2 | Responsive layout (% of dc.getHeight); view-by-reference pattern; YOU/OPP labels; server indicator |
| v1.1.3 | Garmin-style MatchMenu (RESUME/SAVE/LATER/DISCARD); 3× popView exit fix — **APPROVED 2026-05-06/07** |
| v1.1.4 | Resume-after-warm-up fix; change-over indicator; bigger buttons; HR/clock position fix |
| v1.1.5 | Human-readable FIT field names; per-set LAP fields; dropped RECORD fields |
| v1.1.6 | `setData(0)` seed fix — Connect IQ™ section now physically in FIT file |
| v1.1.7 | Super TB engine fix; SetupView format presets (4 named formats); SPORT_GENERIC experiment |
| v1.1.8 | SPORT_GENERIC deployed — confirmed Garmin filters dev fields universally (dead end) |
| v1.1.9 | Reverted to SPORT_TENNIS; submitted to store |
| v1.2.0 | Supabase sync; Singles/Doubles type; Communications permission — submitted 2026-05-20 |
| v1.2.1 | Context-aware FORMAT presets per match type; layout compacted; lap announcements removed |
| v1.3 | On-watch match history (MatchHistory + MatchHistoryView); delete individual match |
| v1.3.1 | Switched Supabase project to Training Hub; updated Secrets.mc + web app constants |

---

## Current Status (as of 2026-05-22)

- ✅ Compiles with warnings only (0 errors)
- ✅ Runs in CIQ Simulator
- ✅ Full scoring engine + undo
- ✅ Setup screen: TYPE / FORMAT / SERVES 1ST / HISTORY / START
- ✅ Main match screen: redesigned layout
- ✅ Post-match summary (2 pages: match stats + health)
- ✅ Match persistence (save/resume)
- ✅ On-watch match history (last 5 matches, deletable)
- ✅ Supabase sync (Training Hub project)
- ✅ ActivityRecording (SPORT_TENNIS, HR, FIT fields, laps per set)
- ✅ Garmin CIQ Store: publicly listed and approved
- ⏳ v1.2.0 awaiting Garmin review
- ⏳ Real-watch test for Supabase sync (verify POST reaches table)
- 📋 Future: web dashboard (Training Hub HTML+JS, Supabase JS SDK, GitHub Pages)

---

## MVP Principle

> "I can play a full set and log every point without frustration."

Don't over-engineer. Build for real court use: tired, one hand, glare.

---

## Future Roadmap

**v1.2 — Multi-device support**
- Refactor all layout coords to use `dc.getWidth()` / `dc.getHeight()` percentages
- Priority order: Vivoactive 5 → Venu 3 → Forerunner 265 (touch) → Epix Pro
- Touchscreen required — exclude non-touch devices

**v1.5/v2.0 — Monetization**
- Keep v1.x free to build downloads + reviews
- Garmin options: paid upfront / trial→unlock / donations (all 30% cut)
- Path A: free MatchMind + paid "MatchMind Pro" companion app
- Path B: in-app unlock (Trial App pattern)
- Revisit 3–6 months after v1.1.1 launch with real user feedback

---

## Key Files Outside Tennistracker/

| File | Purpose |
|---|---|
| `TennisTracker_DECISIONS_LOG.md` | Full detailed decisions log — always keep updated |
| `MatchMind_Architecture_Landscape.html` | Visual architecture overview (dark theme, offline) |
| `GarminTennisCodeReference.docx` | Code reference document |
| `GarminTennisBuildPlan.docx` | Build plan document |
| `matchmind_cover.png` | Store listing cover (500×500) |
| `matchmind_screen.png` | Store listing screenshot (390×390) |
