# MatchMind — Garmin App Decisions Log
*Last updated: May 22, 2026*

---

## 2026-05-22 — Build tooling: store packaging fix

**Problem:** `package.sh` used `monkeyc -r` (release flag) which produces a `.iq` that the Garmin Developer Portal rejects with "error processing manifest file".

**Fix:** Use `monkeyc -e` (export flag) instead. This is the correct flag for store-submission packages.

**Correct command:**
```bash
monkeyc -o bin/Tennistracker.iq -f monkey.jungle -y developer_key -e -w
```

**`package.sh` updated** to use `-e`. Run `./package.sh` for all future store submissions.

**Note on manifest type:** `type="watch-app"` is the only valid type for a CIQ app that records activities. `type="activity"` does NOT exist in the SDK and will cause a build error. The generic stick figure icon in Garmin Connect "Other" is a platform limitation — there is no workaround from a CIQ app.

---

## 2026-05-22 — v1.3.1: switched Supabase project to Training Hub

**Decision:** Move all MatchMind Supabase data from Golf-tracker project to Training Hub project. Reason: Tennis data was already flowing to Training Hub; keeping two projects separate avoids confusion and keeps all training data in one place.

**Files changed:**
- `Secrets.mc` — `SUPABASE_URL` and `SUPABASE_ANON_KEY` updated to Training Hub project (`pmzzmvzbgeonjnbfreze`).
- `PROJ0004_training app/index.html` — `_SB_URL` and `_SB_KEY` constants in Tennis tab updated to Training Hub project.

**Supabase setup required (one-time):**
- Run provided `CREATE TABLE matches` SQL in Training Hub SQL Editor.
- Two RLS policies: anon INSERT (watch app) + anon SELECT (web app).

**Watch app:** rebuild and submit v1.3.1 after running the SQL.

---

## 2026-05-21 — v1.3: on-watch match history

**Two new files:**
- `MatchHistory.mc` — static module (like MatchPersistence). Saves last 5 completed matches to Toybox.Storage. Flat String-keyed dict per match (same rules as all CIQ Storage). Keys: `won`, `setsP`, `setsO`, `sets` (score string), `ptsW`, `ptsL`, `err`, `df`, `date` (unix timestamp), `mtype`.
- `MatchHistoryView.mc` — browse history one match at a time. Swipe LEFT = older, RIGHT = newer. Back button returns to Setup. Shows: date, Singles/Doubles, YOU WIN!/OPP WON, set scores, Pts W/L, Errors, D.Faults. Empty state message if no matches saved yet.

**Existing files changed:**
- `PostMatchView.mc` — `finishAndExit()` now calls `MatchHistory.saveMatch(engine)` before `stopSession` and `clearState`.
- `SetupView.mc` — HISTORY added as 4th navigable row (swipe to reach, tap to open). Shows match count as value (e.g. "3 matches" / "empty"). Layout updated from 3→4 rows; swipe range extended to selectedItem 0–3.

**Delete individual match added:**
- `MatchHistory.deleteMatch(idx)` shifts records down and decrements `histCount`.
- DELETE button (dark red) visible on each match card. Tap → inline YES/NO confirmation overlay (no extra view). YES deletes and adjusts currentIdx if needed. NO/back/swipe cancels.

**Arrow characters fixed:** ◂ / ▸ not supported by Garmin FONT_XTINY — replaced with plain `<` / `>`.

**Decision:** watch-only history, no web dashboard yet. Garmin Connect cannot display custom stats (server-side filter confirmed). Web dashboard via Training Hub web app planned as next step once that codebase is accessible.

---

## 2026-05-21 — v1.2.1: context-aware FORMAT presets + lap fix

**FORMAT presets made context-aware (Singles vs Doubles):**
- Both types now have exactly 3 FORMAT options (index 0–2), cycling on tap.
- **Singles:** 1 Set → Best of 3 → Super TB
- **Doubles:** 1 Set → Best of 3+ST → Super TB
- "Best of 3" means different engine configs per type:
  - Singles: 2 sets to win, tiebreak ON, no super TB
  - Doubles: 2 sets to win, tiebreak ON, super TB decider ON ("Best of 3+ST" label)
- Switching TYPE resets formatPreset to 0 (avoids stale preset from the other type).
- `configFromPreset()` now takes `matchTypeIdx` as second argument.

**Setup screen layout tightened:**
- All 3 rows now use `FONT_XTINY` for both label and value (was `FONT_TINY` for value). Compact but readable.
- Title "MatchMind" reduced from `FONT_SMALL` → `FONT_TINY`.
- Row spacing reduced from `rowH + 12` → `rowH + 8`; gap above START from 24px → 16px.
- All 3 rows (TYPE / FORMAT / SERVES 1ST) + START button now fit cleanly without overlap.

**Lap announcements removed:**
- `_session.addLap()` removed from `markSetEnd()`. The Garmin OS was announcing each set-end lap out loud (beep + vibration), disruptive mid-match.
- LAP custom fields were already being filtered by Garmin Connect server-side, so nothing visible was lost.
- `markSetEnd()` kept as a no-op — call sites in MainDelegate unchanged.

---

## 2026-05-20 — v1.2.0: Supabase sync + Singles/Doubles + submitted to store

**FIT-file diagnosis (confirmed):**
- Inspected FIT file from a real-watch match using Python `fitparse`.
- Confirmed Garmin's server-side filter suppresses developer fields universally — not just for Tennis sport type. This is a dead end; the data is in the FIT file but Garmin Connect won't render it.

**SPORT_TENNIS reverted (v1.1.9 → v1.2.0):**
- Decision: keep `SPORT_TENNIS / SUB_SPORT_MATCH` so the app retains the tennis racket icon and "All Racket Sports" aggregation in Garmin Connect. Switching to `SPORT_GENERIC` gained nothing display-wise (confirmed in v1.1.8 test).

**Supabase backend set up:**
- Backend pivot: reused Jo's existing "Training Hub" Supabase project (no new account, no extra cost, no Mac dependency).
- New `matches` table with 27 columns: all engine-tracked stats + nullable `opponent_name`, `location`, `notes` fields to fill in via dashboard later.
- RLS enabled with "Allow anon access" policy (anon key sufficient for watch POSTs).
- Free tier inactivity pause (7 days) is not a concern — Training Hub gets weekly activity.

**Watch-side Supabase sync added:**
- `Secrets.mc` — holds `SUPABASE_URL` + anon key (gitignored, not in repo).
- `SupabaseSync.mc` — `uploadMatch(engine, manager)` POSTs JSON to `/rest/v1/matches`. Payload: totals, set scores JSON array, format string, result, duration, match_type.
- `manifest.xml` — added `Communications` permission for `makeWebRequest()`.
- `TennisActivityManager.mc` — holds `_supabaseSync` instance; calls `uploadMatch` at end of `stopSession()`. Discarded matches skip the sync.

**Singles/Doubles match type added:**
- `TennisMatchEngine.mc` — new `matchType` field ("singles" / "doubles"), persisted in `getState`/`restore`.
- `SetupView.mc` — TYPE row added at top (Singles / Doubles toggle); setup is now 3 rows: TYPE / FORMAT / SERVES 1ST + START.
- Match type included in Supabase sync payload.

**v1.2.0 submitted to Garmin store.**

---

## 2026-05-18 — Architecture landscape document added
- Created `MatchMind_Architecture_Landscape.html` in the project root.
- Single-file HTML, hybrid format: layered tech stack (Hardware → OS → Monkey C VM → Connect IQ SDK → Resources → App) plus a component flow diagram (App.mc → Views/InputDelegate → MatchEngine → ActivityManager/Persistence → FitContributor → Garmin Connect).
- Includes a 5-step lifecycle, build pipeline diagram, and a beginner-friendly glossary.
- High-level overview style by choice (not detailed map); intended for quick orientation and sharing.
- No external scripts or fonts; renders offline. Dark theme with tennis-ball green accent.

---

## Project Overview
**App name:** TennisTracker (file/manifest name) — branded as **MatchMind**  
**Company branding:** MatchMind Studio  
**Device:** Garmin Vívoactive 6  
**Language:** Monkey C  
**SDK:** Connect IQ 9.1.0  
**API Level:** 6.0  
**Project path:** iCloud Drive → 01 Claude in Docs → 02 Projects → PROJ007_Garmin App → Tennistracker

---

## Current Status
- ✅ App compiles with warnings only (0 errors)
- ✅ Runs in CIQ Simulator
- ✅ Scoring engine (points, games, sets, tiebreak, super tiebreak, undo)
- ✅ Setup screen — fully redesigned with 5 settings rows
- ✅ Main match screen — redesigned layout complete
- ✅ Post-match summary — redesigned, label/value list style
- ✅ Undo — swipe up on match screen
- ✅ Match persistence — save/resume via Toybox.Storage (fully working)
- ✅ Set history tracking in engine and displayed in MainView
- ✅ Serve/return point stats tracked per point
- ✅ Match format: Sets / Tiebreak only / Super TB only
- ✅ Exit flow — both physical buttons show "End Match?" confirmation
- ✅ Launcher icon — 54x54 tennis ball SVG
- ✅ App name — "MatchMind" in strings.xml
- ✅ FitContributor / ActivityRecording implemented — matches saved to Garmin Connect
- ✅ Heart rate recorded throughout match via ActivityRecording session
- ✅ Custom FIT fields: live score, games, sets, winners, errors, double faults
- ✅ Store listing description typo fixed ("ploints" → "points")
- ✅ v1.1.0 submitted to Garmin Connect IQ Store (2026-04-24, Status: Pending)
- ✅ Resume prompt tap-zone bug (hardcoded h=450) fixed — 2026-05-05
- ✅ ConfirmEndDelegate overlapping tap zones fixed — 2026-05-05
- ✅ v1.1.1 built and submitted as **Public** (not beta) — 2026-05-05
- ✅ New appID `a4302e08-340f-4a11-8970-1cb44e7ab34f` in manifest
- ✅ **v1.1.1 APPROVED by Garmin — 2026-05-06** (under 24 hours)
- ✅ Real-watch testing exposed layout overlap + tap crash bugs — 2026-05-06
- ✅ v1.1.2 responsive-layout refactor + view-by-reference pattern — 2026-05-06
- ✅ v1.1.2 polish + server indicator + YOU/OPP labels — 2026-05-06
- ✅ v1.1.2 built and submitted — exit-app loop discovered on second real-watch test
- ✅ v1.1.3 navigation rework + Garmin-style MatchMenu (Resume/Save/Later/Discard) + auto-stop on match end — 2026-05-06
- ✅ **v1.1.3 built and submitted to Garmin store as new version — 2026-05-06**
- ✅ **v1.1.3 APPROVED by Garmin — 2026-05-06/07** (again under SLA)
- ✅ Real-court test of v1.1.3 — exposed pause/resume bug, button sizing, HR clipping, and stats not displayed
- ✅ v1.1.4 built and submitted — 2026-05-07 (resume fix, change-over indicator, lap-per-game, bigger buttons, layout tweaks)
- ✅ v1.1.4 APPROVED + tested on watch — 2026-05-07
- ✅ v1.1.5 built and submitted — 2026-05-08 (proper Garmin Connect™ stats: 12 SESSION fields with human-readable names, 4 LAP fields per set, dropped RECORD fields)
- ❌ v1.1.5 real-watch test — 2026-05-09 — Connect IQ™ section MISSING entirely from Garmin Connect; activity, HR, and 3 laps recorded fine, but no developer field data written
- ✅ v1.1.6 fix in code — 2026-05-09 — seed every developer field with `setData(0)` before `_session.start()`. Hypothesis: createField() alone registers the field definition but emits no data unless seeded.
- ✅ v1.1.6 built, submitted, approved, tested — 2026-05-09–13. FIT-file inspection (Python fitparse) proved: all 16 developer fields are now physically inside the FIT file with correct values (Points won, Errors, Sets won, per-set lap fields, etc.). BUT Garmin Connect (web AND mobile) suppressed the entire Connect IQ™ section anyway. Diagnosis: Garmin's Tennis activity template filters out developer fields server-side.
- ✅ v1.1.7 in code — 2026-05-13 — three changes bundled:
  - **Engine fix** (TennisMatchEngine.mc): super tiebreak now starts AT the beginning of the deciding set, not after the first game is won. New helper `enterSuperTBIfFinalSet()` called from `checkSetWin` and `checkTiebreakWin` after `resetAfterSet`. Old in-the-middle conversion in `checkSetWin` removed.
  - **SetupView refactor** (SetupView.mc): 4-toggle config (FORMAT / SETS / TIEBREAK / SUPER TB) collapsed into one FORMAT preset row with 4 named real-world tennis formats: Best of 3, 2 Sets + STB, 1 Set, Super TB. `configFromPreset()` derives the engine config flags on START. 5 setup rows → 2.
  - **Sport type swap** (TennisActivityManager.mc): `Recording.SPORT_TENNIS` → `Recording.SPORT_GENERIC` to bypass Garmin Connect's Tennis template filter. Activity name stays "Tennis Match". Trade-off: tennis racket icon → generic, no "All Racket Sports" aggregation. Gain: Connect IQ™ section with all 12 SESSION fields + 4 LAP per-set fields actually displays.
- ✅ v1.1.7/1.1.8 built, submitted, real-watch tested — 2026-05-13/14. New 2-row setup screen renders cleanly (with stacked label/value after the initial overlap fix). Super tiebreak engine fix verified in sim. BUT: SPORT_GENERIC did NOT make the Connect IQ™ section appear — confirmed via FIT-file inspection of the v1.1.8 match. The FIT file contains all 16 dev fields with correct values AND has `sport=generic`, so the swap deployed correctly. Garmin Connect filters developer fields **universally**, not just for Tennis. Conclusion: switching sport types is a dead end.
- ✅ v1.1.9 in code — 2026-05-14 — REVERTED `SPORT_GENERIC` → `SPORT_TENNIS` / `SUB_SPORT_MATCH`. Since the swap gained nothing display-wise, keep tennis categorization (icon, Tennis Reports aggregation, racket-sport grouping). Stats remain in FIT file for future tools.
- ✅ v1.1.9 submitted to Garmin store — 2026-05-14
- ✅ **v1.2.0 submitted to Garmin store — 2026-05-20:**
  - Supabase backend wired up (matches table, RLS, anon key)
  - `Secrets.mc` + `SupabaseSync.mc` added to watch code
  - Singles/Doubles match type added to engine + SetupView
  - `Communications` permission added to manifest
  - SPORT_TENNIS retained (revert from SPORT_GENERIC experiment)
  - ⏳ Awaiting Garmin approval
  - ⏳ Real-watch test (verify HTTP POST reaches Supabase, row appears in `matches` table)
  - 📋 Future: small web view (HTML+JS using Supabase JS SDK) for browsing matches from phone/laptop. Could host on the same GitHub Pages as Training Hub.
- 🗑️ Old beta listing (appID `fa28b1ed-5ff7-46d3-86dc-026b88b7025a`) can be removed via Remove button

---

## MVP Milestone
> "I can play a full set and log every point without frustration."

**What NOT to build first:** health tracking, fancy UI, too many stats, swing detection.

---

## Architecture (5 Modules)
1. **TennisMatchEngine** — scoring logic (points → games → sets), deuce, tiebreak, super tiebreak, undo, serve tracking
2. **Input Handler** — WON / ERROR / DOUBLE FAULT inputs
3. **History Manager (Undo)** — stack-based state snapshots (max 50 entries)
4. **Health Tracker** — heart rate, steps via Toybox.Activity (FIT recording disabled)
5. **UI Layer** — SetupView, MainView, ConfirmEndView, PostMatchView

---

## Source Files

| File | Purpose |
|---|---|
| App.mc | Entry point — launches SetupView via getInitialView() |
| SetupView.mc | Pre-match config (format, sets, tiebreak, super TB, serves first) |
| MainView.mc | Match screen + ConfirmEndView (end match confirmation) |
| TennisMatchEngine.mc | Core scoring logic (points, games, sets, undo, all stats) |
| TennisActivityManager.mc | HR sensor reading (FIT recording disabled for now) |
| PostMatchView.mc | Post-match summary (stats, duration, HR) |
| MatchPersistence.mc | Save/resume match state via Toybox.Storage |
| Secrets.mc | SUPABASE_URL + anon key (gitignored) |
| SupabaseSync.mc | POSTs match JSON to Supabase `/rest/v1/matches` at end of session |

---

## Main Match Screen Layout

```
┌──────────────────────────────┐
│   HR:115        22:30        │  ← status bar (HR left, clock right)
│          00:18               │  ← match timer (center)
├──────────────────────────────┤
│  P1   GAMES    P2            │  ← player labels + "GAMES" label
│        1-5                   │  ← current game score (center)
│        6-0                   │  ← set history (gray, center)
│  [●]           40            │  ← green oval + big points (FONT_NUMBER_MILD)
├─────────────────────────────-┤
│  [ ERROR ]    [ D.FAULT ]    │  ← red outline buttons
├──────────────────────────────┤
│          MatchMind           │  ← branding
└──────────────────────────────┘
```

**Touch interactions:**
- Tap top half → P1 won the point (green flash)
- Tap ERROR (bottom left) → opponent won — unforced error (red flash)
- Tap D.FAULT (bottom right) → opponent won — double fault (orange flash)
- Swipe UP → undo last point (blue flash)
- Physical button (top or lower green) → "End Match?" confirmation

**Key layout constants (MainView.mc):**
- `STATUS_DIVIDER_Y = 78`
- `BUTTON_Y = 252`, `BUTTON_BOTTOM_Y = 302`
- `P1_X = 90`, `P2_X = 300`, `CENTER_X = 195`
- Button inset = 78 (keeps buttons inside round screen bounds)

---

## SetupView Settings (in order)

| Row | Setting | Options | Notes |
|---|---|---|---|
| 1 | FORMAT | Sets / Tiebreak / Super TB | Tiebreak/Super TB rows dim when not Sets |
| 2 | SETS | Best of 1 / Best of 3 | Disabled when FORMAT ≠ Sets |
| 3 | TIEBREAK | ON / OFF | Disabled when FORMAT ≠ Sets |
| 4 | SUPER TB | ON / OFF | Disabled when FORMAT ≠ Sets |
| 5 | SERVES 1ST | You / Opp | Always active |
| — | START | — | Green button, launches match |

**Swipe** navigates rows; swipe skips disabled rows automatically when FORMAT ≠ Sets.

---

## Match Formats

| Format | Behaviour |
|---|---|
| Sets | Normal tennis — full sets, tiebreak at 6-6 (if on), super TB for final set (if on) |
| Tiebreak | Single tiebreak to 7 points (lead by 2). Score shown as actual points e.g. 9-7 |
| Super TB | Single super tiebreak to 10 points (lead by 2) |

**Bug fix:** Best-of-1 + Super TB no longer triggers super tiebreak after the first game. Guard: `setsToWin >= 2` required for super tiebreak activation.

---

## Scoring Logic (TennisMatchEngine)
- Points: 0 → 15 → 30 → 40 → Deuce → Advantage → Game
- Tiebreak at 6-6 (first to 7, lead by 2)
- Super tiebreak for final set (first to 10, lead by 2)
- Server rotates: switches after every game; in tiebreaks: 1 point then every 2
- WON (0) = player wins point | ERROR (1) = opponent wins (unforced error) | DOUBLE_FAULT (2) = opponent wins
- Undo stack: max 50 snapshots, full state restored including serve tracking

---

## Stats Tracked Per Player

| Stat | Description |
|---|---|
| winners | Points won (WON inputs) |
| unforcedErrors | Points lost via ERROR input |
| doubleFaults | Points lost via DOUBLE_FAULT input |
| servePtsPlayed | Points played while serving |
| servePtsWon | Points won while serving |
| returnPtsPlayed | Points played while returning |
| returnPtsWon | Points won while returning |

**Points W/L** in summary = `winners` / `unforcedErrors + doubleFaults` (always consistent with individual rows).

---

## Post-Match Summary (Page 1)

```
     MATCH SUMMARY
      OPPONENT WON          ← green if you won, red if not
  ─────────────────────
  Sets     │ 1-2            ← or "TB Score" / "Super TB" for tiebreak formats
  Pts W/L  │ 15 / 19
  Srv Pts  │ 12/19
  Ret Pts  │ 3/15
  Winners  │ 15
  Errors   │ 4
  D.Faults │ 15
  Duration │ 0m 14s
```

Page 2 (swipe left): Health stats (HR avg/max, steps, calories if available).

---

## Exit / End Match Flow

```
Mid-match → press either physical button
                ↓
         END MATCH?
         [ YES ] → PostMatchView (partial or full stats)
         [ NO  ] → back to match (nothing lost)
         (any button on confirm screen = NO)

PostMatchView → press BACK → SetupView (clears saved state)
```

**Implementation:** `onBack()` + `onKey()` both call `showConfirm()` in MainDelegate. `onKey()` catches any key (no hardcoded key constant — avoids device-specific mapping issues). `drawRoundedRectangle` not used (API 6.0 only has `fillRoundedRectangle`); NO button uses `drawRectangle`.

---

## Tech Decisions

| Decision | Choice | Reason |
|---|---|---|
| Delegate base class | `Ui.InputDelegate` | TouchDelegate removed in API 6.0 |
| Activity recording | Enabled — `Toybox.ActivityRecording` + `Toybox.FitContributor` | Tennis match saved to Garmin Connect with custom FIT fields |
| Timer-based feedback | Removed | Timer callback type too strict in API 6.0; replaced with 2-frame redraw |
| View type casting | `Ui.getCurrentView()[0] as ViewName` | Required by Monkey C type checker in SDK 9.x |
| Entry point | `getInitialView()` only | `onStart()` + `getInitialView()` caused double-push crash |
| Developer key | Stored in Tennistracker/developer_key | Generated via Monkey C: Generate Developer Key |
| Java | Temurin via Homebrew | java.com installer incompatible with Apple Silicon |
| `drawRoundedRectangle` | Not used | Doesn't exist in API 6.0 — use `fillRoundedRectangle` or `drawRectangle` |
| Physical button key | `onKey()` catches all keys | Avoids hardcoding key constants that differ by device |
| Points total display | Computed from winners/errors/doubleFaults | Always consistent with individual stat rows |
| Tiebreak-only score | Actual points stored in setHistory | In-set tiebreaks use 7-6 convention; standalone shows real score e.g. 9-7 |
| Storage serialization | Flat String-keyed dict, primitives only | CIQ Storage crashes on Symbol keys (`:name`) and nested dicts — all state flattened to `"pPoints"`, `"oGames"` etc. |
| setHistory in Storage | Two parallel Number arrays `"shP"` / `"shO"` | Cannot store array of Symbol-keyed dicts in Storage |
| Vivoactive 6 USB | No mass storage mode | Newer Garmin devices dropped USB drive mode — install via Connect IQ Store only |
| Store distribution | Public submission planned for v1.1.1 | Beta dropped (dev-only, can't reach personal-account watch). New appID: `a4302e08-340f-4a11-8970-1cb44e7ab34f` (old beta appID was `fa28b1ed-5ff7-46d3-86dc-026b88b7025a`). Garmin requires a new appID when moving beta → public. |
| Devices supported | Vivoactive 6 only (v1.1.1) | Hardcoded layout coords sized for 390×390. Multi-device support deferred to v1.2 — needs responsive layout refactor. |

---

## How to Build & Run

**Easy way — use run.sh from Mac Terminal:**
```bash
cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/01\ Claude\ in\ Docs/02\ Projects/PROJ007_Garmin\ App/Tennistracker
./run.sh
```
Open the CIQ Simulator first, then run the script.

**Manual build (simulator):**
```bash
cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/01\ Claude\ in\ Docs/02\ Projects/PROJ007_Garmin\ App/Tennistracker && ~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin/monkeyc -o bin/Tennistracker.prg -f monkey.jungle -y developer_key -d vivoactive6_sim -w
```

**Build for store (.iq package):**
```bash
cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/01\ Claude\ in\ Docs/02\ Projects/PROJ007_Garmin\ App/Tennistracker
"$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin/monkeyc" -o bin/Tennistracker.iq -f monkey.jungle -y developer_key -e -w
```

**Run in simulator:**
```bash
~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin/monkeydo bin/Tennistracker.prg vivoactive6
```

---

## Data Persistence
- Uses `Toybox.Storage` (local on watch)
- Saves: full engine state including matchFormat, serve tracking, set history
- Restores on app reopen — "Resume match?" prompt
- Cleared when exiting from PostMatchView (BACK button)

---

## Known Issues / Remaining To Do
- [x] Launcher icon updated — 54x54 tennis ball SVG (yellow-green ball, white seam arcs)
- [x] App name updated — strings.xml AppName changed from "Tennis tracker" to "MatchMind"
- [x] FIT recording (Garmin Connect activity) — implemented in v1.1.0
- [ ] Health page (PostMatchView page 2) — HR/steps only show if activity sensor active
- [x] Fix store listing typo: "ploints" → "points" — fixed in v1.1.0 submission
- [x] Undo in tiebreak-only formats — code verified correct; all state fields saved/restored
- [x] Match persistence — fully working (save, resume prompt, restore, undo after resume, finish match)

---

## Future Roadmap

### v1.2 — Multi-device support
**Goal:** expand beyond Vivoactive 6 to reach more users once v1.1.1 is approved and stable.

**Prep work (one-time):**
- Refactor `MainView.mc` layout to use percentages of `dc.getWidth()` / `dc.getHeight()` instead of hardcoded pixels (`BUTTON_Y = 252`, `P1_X = 90`, `BUTTON_BOTTOM_Y = 302`, etc.). ~2–3 hours.
- Same refactor for `SetupView.mc`, `PostMatchView.mc`, `ResumePromptView.mc`, `ConfirmEndView.mc`.

**Device rollout order (easiest → hardest):**
1. **Vivoactive 5** (390×390, same as VA6) — minimal testing, likely no code changes
2. **Venu 3S** (390×390) — likely no code changes
3. **Venu 3** (454×454) — verify layout scales up cleanly
4. **Forerunner 165 / 265 / 265S / 965** (touch variants only) — round AMOLED, similar specs
5. **Epix Pro / Fenix 7 Pro / Fenix 8** (touch variants) — larger screens, premium users
6. **Venu Sq 2** (240×280, *square*) — only after square-layout testing; lowest priority

**Submission:** new version of *same* app (no new appID). Re-review ~3 days.

**Touchscreen requirement:** the app fundamentally requires a touchscreen for scoring. Watches without touch (most Forerunners under 165, Instinct, classic Fenix) are excluded.

### v1.5 / v2.0 — Monetization
**Strategy:** keep v1.x free to maximize downloads + reviews on a new dev account. Introduce paid model only after building track record and identifying what users want to pay for.

**Garmin's monetization options:**
| Model | How it works | Garmin cut |
|---|---|---|
| Paid upfront | Fixed price, user pays before install | 30% |
| Trial → unlock | Free install, in-app payment unlocks features (uses Trial App callback credentials already on the dev dashboard) | 30% |
| Donations | Voluntary tips from users | 30% |

**Setup required (when ready):** complete Merchant Account tab on developer dashboard (tax info + payout details).

**Two viable paths:**
- **Path A — "MatchMind Pro" companion app:** keep MatchMind free, release a separate paid app with opponent profiles, doubles support, season stats, CSV export, etc.
- **Path B — In-app unlock:** free MatchMind with limited match history; pay to unlock unlimited matches, advanced stats, export. Uses the Trial App pattern.

**Revisit timing:** earliest 3–6 months after v1.1.1 launch, once there's real user feedback on what features they'd pay for.

---

## Jo's Preferences
- Complete beginner to app development
- Wants clear step-by-step explanations
- Designing for real use: tired, during a match, one hand
- App branding by company: MatchMind Studio
- Keep explanations brief and to the point
- Always maintain this decisions log

---

## Session History
- **2026-05-13:** v1.1.7 — three real-court bugs fixed in one release:
  - **The FIT-file investigation paid off.** v1.1.6 was approved and tested on a real 2:20 match. Garmin Connect *still* showed no Connect IQ™ section. Downloaded the FIT file from Garmin Connect (Export File → .fit), ran it through Python's `fitparse` library — and found ALL 16 developer fields physically inside the file with correct values (Points won = 59, Errors = 25, per-set lap data, etc.). Conclusion: our app has been writing the data correctly since at least v1.1.5; Garmin's Tennis activity template is suppressing custom developer fields server-side, on both web and mobile views. v1.1.6's `setData(0)` fix was real and necessary (without it the field-definition block stays empty), but it wasn't sufficient by itself to make Garmin Connect display the data.
  - **Sport type swap.** Changed `Recording.SPORT_TENNIS` → `Recording.SPORT_GENERIC` in `TennisActivityManager.startSession()`. Garmin's tennis-specific UI template no longer filters our fields. Activity name "Tennis Match" preserved (cosmetic — only the icon and category change). HR / calories / training effect / body battery all keep working. Daneel's reference app appears to be grandfathered in from 2019 — its approach isn't reproducible with the current API, so we go around the filter instead.
  - **Super tiebreak engine fix.** Real-court test of v1.1.6 doubles match exposed a separate bug: with sets at 1-1 and superTiebreakFinalSet=true, set 3 was starting as a normal set and only converting to super TB *after* the first game was won (with confusing score reset). Now handled by a new `enterSuperTBIfFinalSet()` helper called immediately after `resetAfterSet` in `checkSetWin` and `checkTiebreakWin` — super TB is set up before any points are played in set 3, so the score reads "0-0 SUPER TIEBREAK" cleanly. Old in-the-middle conversion in `checkSetWin` removed.
  - **SetupView simplified to format presets.** Jo's UX feedback: four toggle rows (FORMAT / SETS / TIEBREAK / SUPER TB) were confusing and easy to misconfigure (a doubles match with super TB off → no auto super TB). Replaced with one FORMAT row that cycles through 4 named real-world tennis formats: **Best of 3** (singles standard, doubles finals), **2 Sets + STB** (doubles compact, college, most pro doubles), **1 Set** (quick match), **Super TB** (single 10-point super tiebreak). A `configFromPreset()` helper translates the preset back into the existing engine config flags so no engine refactor was needed. Setup screen dropped from 5 rows to 2 (FORMAT + SERVES 1ST + START button). Jo's other observation — that she only configures match after warm-up because the racket spin decides serves — confirms SERVES 1ST stays in setup; she's fine choosing it then.
  - **Other findings logged for later:** (a) screen dimming on Vivoactive 6 AMOLED during long no-touch periods needs AOD implementation, not fixed in v1.1.7. (b) System notifications during a match overlay the screen and don't auto-dismiss — this is a CIQ "watch-app" limitation, not fixable in our architecture. Workaround: phone-side Focus / DND. Watch-side DND would dim the screen, defeating the purpose.
- **2026-05-09:** v1.1.6 — fix Connect IQ™ section missing in Garmin Connect:
  - **Real-watch test of v1.1.5 finding:** Activity saves fine (HR + 3 laps recorded), but Activity Stats tab has NO "Connect IQ™" section at all — meaning the developer fields aren't reaching the FIT file. Compared to Daneel's reference app screenshot, which DOES show a Connect IQ section with "0 points" for fields that weren't tracked — proving Garmin Connect would render the section even with zero values, IF the fields were registered.
  - **Hypothesis:** `createField()` alone only registers the field *definition* in the FIT file. Field *data* is only emitted when `setData()` has been called at least once. Without an initial seed, the developer field block is empty when the session starts → Garmin Connect strips it from display entirely.
  - **Fix (TennisActivityManager.startSession):** added a 16-line block of `setData(0)` calls right before `_session.start()` — one for each of the 12 SESSION fields and 4 LAP fields. Real values still get written by `markSetEnd()` (lap fields) and `writeSessionFields()` (session fields) at their normal call sites. The seed is purely an initialization safeguard.
  - **Side-question raised:** Garmin's OS lap-popup ("first lap, 0:32") fires every time `_session.addLap()` is called — that's expected behavior at end-of-set in v1.1.5+. Trade-off accepted: per-set Laps tab data > clean mid-match UX. Revisit only if it becomes annoying in real play.
  - **Untested:** sim build + real-watch verification still pending. If Connect IQ section now appears with values, ship v1.1.6 to store. If section appears but values are 0, dig deeper. If section still missing, next try is removing `:units => "points"` (might be a non-standard FIT unit).
- **2026-04-15:** Project folder accessed, full PDF read (75 pages). Complete Monkey C code for all modules. Ready to start building.
- **2026-04-18:** Decisions logs merged into single file. Main screen redesign started.
- **2026-04-19:** Major session — full redesign completed:
  - SetupView: spacing fixed, 5 rows, FORMAT selector (Sets/Tiebreak/Super TB), SERVES 1ST option, hint text removed
  - MainView: new split layout (P1 left/center/P2 right), GAMES label + score, set history, green oval, ERROR/D.FAULT buttons with correct insets, MatchMind branding, swipe-up undo
  - TennisMatchEngine: set history tracking, serve/return point stats (4 new counters), server rotation logic (game + tiebreak), matchFormat field, Best-of-1 super tiebreak bug fixed
  - PostMatchView: label/value list style (inspired by Garmin reference), 8 stat rows, format-aware first row label, MATCH SUMMARY clipping fixed
  - ConfirmEndView: new "End Match?" screen triggered by both physical buttons (onBack + onKey), YES/NO tap zones, drawRoundedRectangle bug fixed
- **2026-04-20:** Bug fixes and testing session:
  - **Launcher icon:** Updated 24x24 placeholder → 54x54 tennis ball SVG (yellow-green, white seam arcs). App name in strings.xml changed to "MatchMind".
  - **PostMatchDelegate.onKey():** Added missing handler — lower green button now exits to SetupView (same as BACK). Previously the user was stuck on the summary screen.
  - **MatchPersistence.saveState() crash:** Removed call from onTap — was causing runtime crash (untested code path). Match persistence deferred to future session.
  - **Undo crash (CRITICAL):** `Array.remove(index)` in Monkey C removes by VALUE not index — returned null, crashing on `null[:player]`. Fixed using `history[lastIdx]` + manual copy loop.
  - **Undo exits to setup:** `Array.slice(0,0)` returns null in Monkey C → `history.size()` on null caused silent crash → CIQ popped the view. Fixed by rebuilding array with a for loop instead of slice.
  - **Swipe consuming:** MainDelegate.onSwipe now returns true for ALL directions to prevent system back-navigation on swipe-left.
  - **Simulator path:** ConnectIQ simulator app is `ConnectIQ.app` (not `ConnectIQSimulator.app`). Updated run.sh comment with correct path.
  - **Undo confirmed working:** Up/down swipe both trigger undo. All points can be undone without crashes or unintended navigation.
- **2026-04-20 #2:** Match persistence fully fixed and tested:
  - **Root cause:** CIQ Storage cannot serialize Symbol keys (`:name`) or nested dictionaries. `getState()` was storing player/opponent as nested Symbol-keyed dicts — crashed on `Storage.setValue()` every time.
  - **Fix:** Rewrote `getState()` to produce a completely flat dictionary with String keys and primitive values only. Player/opponent fields stored individually (`"pPoints"`, `"oGames"`, etc.). Set history stored as two parallel Number arrays (`"shP"`, `"shO"`).
  - **Fix:** `restore()` reconstructs internal Symbol-keyed player/opponent dicts from flat values. Engine works identically after restore.
  - **Fix:** `resumeMatch()` in MatchPersistence updated to read String keys (`"matchFormat"`, `"tbEnabled"`, `"superTBFinal"`).
  - **Confirmed working:** Score points → close simulator → reopen → "Resume match?" → YES → score restored. Undo, finish match, and new match setup all work correctly after resume.
- **2026-04-22:** Store submission and sideloading session:
  - **Match persistence root cause fixed:** CIQ Storage crashes on Symbol keys and nested dicts. Rewrote `getState()` to use flat String-keyed dict with primitives only. `restore()` reconstructs internal dicts from flat values. Fully tested and working.
  - **Build for store:** `.iq` package built using `monkeyc -e` flag.
  - **Garmin Connect IQ Store:** App submitted as beta under MatchMind Studio developer account. App ID: `f30dd7fa-cd29-4ed4-a672-efb97c9e8394`. Status: Pending.
  - **Store assets created:** `matchmind_cover.png` (500x500) and `matchmind_screen.png` (390x390 match screen mock).
  - **Sideloading notes:** Vivoactive 6 does NOT support USB mass storage mode. Garmin charging cable is data-capable but watch has no USB drive mode. Install via Connect IQ Store (beta) once status turns Active.
  - **Store listing typo:** Description says "ploints" — fix via Edit Details on apps.garmin.com.
  - **Install URL:** `https://apps.garmin.com/apps/f30dd7fa-cd29-4ed4-a672-efb97c9e8394`
- **2026-04-24:** FitContributor + ActivityRecording implementation:
  - **Context:** App was in Pending status on Garmin store (submitted 2026-04-22). Noticed `FitContributor` and `Sensor` declared in manifest but code only had placeholder — no actual FIT recording.
  - **Decision:** Implement FitContributor properly since heart rate + Garmin Connect sync is core to the app's value (matches should count as activities).
  - **TennisActivityManager.mc:** Full rewrite — starts a `SPORT_TENNIS / SUB_SPORT_MATCH` ActivityRecording session, creates 9 custom FIT fields (4 RECORD time-series: p_pts, o_pts, p_games, o_games; 5 SESSION end-of-match: p_sets, o_sets, winners, errors, dfaults).
  - **Flow wired up:** Manager created + `startSession()` called in SetupView and ResumePromptDelegate. `updateMetrics()` called after every point in MainDelegate. `stopSession()` called in PostMatchDelegate on exit (saves activity to Garmin Connect).
  - **Manager threaded through:** All views/delegates updated to accept and pass `manager` — MainView, MainDelegate, ConfirmEndDelegate, PostMatchView, PostMatchDelegate.
  - **Manifest permissions:** Required both `Fit` (for ActivityRecording) AND `FitContributor` (for Toybox.FitContributor module). Simulator build only needed `Fit`; package/export build needed both. Final manifest has both.
  - **v1.1.0 submitted** to Garmin Connect IQ Store with description typo fixed.
- **2026-04-19 #2:** Bug fixes from code review:
  - **CRITICAL fix:** `MatchPersistence.saveState(engine)` was never called after points — match persistence didn't work at all. Now called in `MainDelegate.onTap()` after every `handleInput()`.
  - **Super tiebreak start score:** `winner[:points] = 1` in `checkSetWin()` caused super tiebreak to start 1-0 instead of 0-0. Fixed to `winner[:points] = 0`.
  - **ConfirmEndDelegate.onKey():** Was checking `KEY_ENTER` specifically — inconsistent with MainDelegate. Changed to catch any key (same pattern as MainDelegate).
  - **Minor:** Added `:matchFormat` to `resumeMatch()` config in MatchPersistence — was missing but restore() compensated; now explicit.
- **2026-05-08:** v1.1.5 — proper Garmin Connect™ stats display (real fix this time):
  - **Discovery:** Jo found her old Vivoactive 3 tennis app (Daneel's "Tennis Tracker") *did* show match stats in Garmin Connect, in a section labeled "Connect IQ™" with proper labels like "Points won", "Unforced errors", etc. Compared field naming and realised our v1.1.4 used short codes (`p_pts`, `winners`) that Garmin Connect filters out as unrecognised. Fix: human-readable field names matching Daneel's pattern.
  - **Engine refactor (TennisMatchEngine.mc):**
    - Added per-set running counters to player/opponent dicts: `setWinners`, `setUnforcedErrors`, `setDoubleFaults`. Reset in `resetAfterSet()`.
    - Added match-level tiebreak counters: `tiebreakPointsWon`, `tiebreakPointsLost`, `tiebreaksWon`. Incremented in `handleInput()` (when `inTiebreak || inSuperTiebreak`).
    - Added engine-level snapshot fields `lastSetWinners` / `lastSetUnforcedErrors` / `lastSetDoubleFaults` / `lastSetTiebreakResult` captured in new helper `captureSetEnd(tbResult)`, called from `checkSetWin` (result=0), `checkTiebreakWin` (1=player won, 2=opp won), `checkSuperTiebreakWin` (same).
    - All new fields persisted in `getState`/`restore` and undo-history snapshots.
  - **Manager refactor (TennisActivityManager.mc):**
    - Dropped the four `MESG_TYPE_RECORD` fields (`p_pts`, `o_pts`, `p_games`, `o_games`) — these were silently filtered out by Garmin's Tennis template and produced no visible value.
    - Replaced 5 short-named SESSION fields with 12 human-readable ones, matching Daneel's display pattern: "Points won", "Errors", "Double faults", "Games won", "Games lost", "Sets won", "Sets lost", "Tiebreaks won", "Tiebreak points won", "Tiebreak points lost", "Service points won", "Return points won". Field IDs 0–11.
    - Added 4 new `MESG_TYPE_LAP` fields for per-set data: "Set points won", "Set errors", "Set double faults", "Set tiebreak" (0=none, 1=player won, 2=player lost). Field IDs 12–15.
    - Replaced `markGameEnd()` with `markSetEnd(engine)` that reads `engine.lastSet*`, writes the LAP fields, and calls `_session.addLap()`. Garmin Connect's Laps tab now shows ONE row per set with per-set stats.
    - `updateMetrics()` is now a no-op kept for call-site compatibility.
    - `stopSession()` writes the 12 SESSION fields once at match end via `writeSessionFields(engine)`.
  - **MainDelegate change (MainView.mc):**
    - Now snapshots only `sets` total (not games) before `handleInput`, calls `markSetEnd(engine)` only when a set just completed.
    - Per-game lap tracking from v1.1.4 is gone — was useful for timing but per-set is more meaningful and shows tennis-specific data.
  - **Trade-off accepted:** lose per-game timing rows in Garmin Connect's Laps tab, gain per-set stats with custom fields. Better for analyzing match flow.
- **2026-05-07:** v1.1.4 — first-real-court polish + change-over indicator + lap recording:
  - **Resume-after-warm-up bug fixed.** `MatchPersistence.saveState(engine)` now called immediately after `new TennisMatchEngine` in `SetupDelegate.startMatch`, and again in `MatchMenuDelegate.executeOption(LATER)`. Previously state was only saved per-point — so starting a match without scoring left nothing to resume.
  - **Change-over indicator (NEW FEATURE).** Tennis rule: switch ends after every odd-numbered game of a set, and every 6 points in a tiebreak. Engine now sets `needsChangeover = true` in `winGame()` (when total games in set is odd) and in `awardPoint()` for tiebreak modes (when total points is a multiple of 6). MainView shows yellow "* SWITCH ENDS *" banner where the divider line normally is, replacing the divider for the duration. Flag clears when next point is scored. Persisted in `getState`/`restore` and undo history.
  - **Lap-per-game FIT recording.** Each completed game writes a lap marker via `_session.addLap()`. Custom developer fields (sets/winners/errors) are still written but Garmin Connect mobile has a built-in Tennis template that hides them. Laps however ARE displayed reliably — so the activity's Laps tab on the phone now shows the match game-by-game with per-game timing and HR. Detected in `MainDelegate.onTap` by snapshotting game/set totals before `handleInput` and comparing after.
  - **Bigger ERROR/D.FAULT buttons.** Visual rectangle now matches the actual tap zone exactly (was inset 4px making them look smaller than they are). Inset narrowed from 20% → 16% of width for wider buttons. Label font bumped from `FONT_XTINY` → `FONT_TINY` for legibility mid-rally. Button band height increased (top 65% → bottom 84%).
  - **HR/clock pushed down.** Status bar moved from y=5%/15% → y=8%/17%, and divider 20% → 23%. Round bezel no longer clips the HR text edges on real watch.
  - **Setup spacing.** `rowsBottom` from `startBtnY - 22` → `startBtnY - 36`. SERVES 1ST now has clear air below it before the green START button.
  - **Roadmap captured for v1.2:** Training mode (separate format with optional scoring + mistake tracking).
- **2026-05-06 #5:** Garmin-style MatchMenu added (replaces 2-button End Match? confirm):
  - **Inspired by:** Garmin's native activity-stop menu (Jo shared a photo). Vertical list with rounded option boxes, yellow highlight ring on the selected item, icon + label per row. Same pattern users already know from running/cycling/etc.
  - **Four options:** RESUME (back to match), SAVE (end + save activity to Garmin Connect + show stats), LATER (leave app, match auto-saved for resume), DISCARD (throw match away — requires confirmation).
  - **Two ways to pick:** tap directly on an option, OR swipe UP/DOWN to highlight + press BACK to confirm.
  - **DISCARD confirmation:** separate red "DISCARD?" view with YES/NO buttons. NO returns to the menu.
  - **New file:** `Tennistracker/source/MatchMenu.mc` containing `MatchMenuView`, `MatchMenuDelegate`, `DiscardConfirmView`, `DiscardConfirmDelegate`. Icons drawn from primitives (fillPolygon, drawLine, drawCircle) — no bitmap resources needed.
  - **`TennisActivityManager.discardSession()` added** — stops recording without calling save(), so the activity is dropped instead of synced to Garmin Connect. Uses `Session has :discard` capability check for forward compatibility.
  - **Old `ConfirmEndView` / `ConfirmEndDelegate`** still in `MainView.mc` but no longer referenced — dead code, will clean up in a future version.
- **2026-05-06 #4:** Navigation rework for v1.1.3 after second real-watch test:
  - **Real-watch findings:** upper button now reaches Setup correctly (v1.1.3 popView fix), but the lower button on Vivoactive 6 triggers a system-level activity-pause indicator (blue triangle) — Garmin's OS intercepts the start/stop button when an ActivityRecording session is active. We can't override that without disabling FIT recording (which would break Garmin Connect sync, the core feature).
  - **New navigation model:**
    - **BACK button** = leave app. Match auto-saves on every point via MatchPersistence; on next launch the user gets the Resume match? prompt. No End Match dialog — clean exit. Stack: pops Main → Setup → app exits.
    - **Lower (start/stop) button** = also tries to open End Match? dialog via `onKey`, but on real watch the system usually intercepts it first. Acceptable — swipe is the reliable path.
    - **Swipe DOWN** (NEW) = opens End Match? dialog. Reliable, no system interference.
    - **Swipe UP** = undo last point (was UP/DOWN both — DOWN now used for End Match).
    - **End Match? YES** → Summary → BACK → 3 popViews unwind to Setup → app exits naturally.
    - **End Match? NO** → back to match.
  - **What this gives Jo:** quit-match-with-stats (swipe DOWN → YES), pause-and-leave (BACK), resume (next launch → prompt), navigate watch in between (system handles, app safely backgrounded). All from her wishlist.
- **2026-05-06 #3:** 🚨 **v1.1.2 real-watch test passed everything except exiting the app:**
  - **What worked on real watch:** layout, scoring, undo, server indicator, YOU/OPP labels, end-match flow YES/NO, FIT recording (activity successfully appeared in Garmin Connect with all stats).
  - **The bug:** after viewing Match Summary and pressing the back/key button, user got bounced through End Match? → Match → repeating loop. Couldn't exit MatchMind without powering off the watch.
  - **Root cause:** `PostMatchDelegate.onBack` used `Ui.switchToView(new SetupView())`, which replaces only the *top* of the view stack. The stack was `[SetupView_orig, MainView, ConfirmEndView, PostMatchView]`. switchToView left `[SetupView_orig, MainView, ConfirmEndView, SetupView_new]`. Pressing back on the new SetupView popped it → exposed ConfirmEndView → user bounced.
  - **Fix (v1.1.3):** replaced switchToView with three consecutive `Ui.popView` calls (SLIDE_RIGHT then two SLIDE_IMMEDIATE). Stack unwinds to `[SetupView_orig]`. From there the watch's back button exits the app cleanly. Resumed-match path (which has only `[MainView, ConfirmEndView, PostMatchView]` because the resume prompt replaced root) exits the app at the third pop — acceptable behavior.
  - **No engine changes needed.** Activity recording / FIT contributor / Garmin Connect sync confirmed working in real-watch test.
- **2026-05-06 #2:** 🚨 **Real-watch testing exposed two critical bugs in v1.1.1**:
  1. **Setup screen rows overlap on real device** — hardcoded y-coordinates (76, 106, 134, 162, 190, 218) were tuned for the simulator. On the actual Vivoactive 6, system fonts render slightly taller and rows collide into each other.
  2. **Tap on Setup screen triggers IQ! crash icon** — root cause: `Ui.getCurrentView()[0] as SetupView` pattern. In CIQ API 6.0, `Ui.getCurrentView()` returns the View directly, not an array, so the `[0]` index crashes the runtime.

  **v1.1.2 polish + new feature (2026-05-06, after first sim test):**
  - **Player labels renamed P1/P2 → YOU/OPP** — much clearer at a glance during a match than "P1"/"P2". Underline below YOU widened to match the longer text.
  - **Server indicator (NEW FEATURE)** — small tennis-ball-yellow filled circle (radius 6, color `0xC8E63C` matching the launcher icon) drawn above whichever player is currently serving (above YOU or above OPP). The engine's `playerServing` flag already rotates correctly between games and within tiebreaks, so no engine logic needed — just a draw call in `MainView.drawScoreArea`.
  - **Match Summary clipping fixed** — title was "MATCH SUMMARY" in FONT_XTINY at y=h\*7/100 → clipped by round bezel. Changed to "SUMMARY" at y=h\*12/100. Result text "OPPONENT WON" → "OPP WON" so it fits the narrower visible chord at the top of the round screen.
  - **Resume match? screen** — buttons enlarged from 70×36 to ~28%×14% of screen. Title and hint pushed up, buttons get more vertical room. Delegate now reads view's button bounds (consistent with the view-by-reference pattern used elsewhere).
  - **Setup screen** — increased gap between SERVES 1ST and START button (rowsBottom now `startBtnY - 22` instead of `-10`).
  - **PostMatch row spacing** — tightened so Duration row doesn't crowd the round bezel at bottom (firstRowY h\*30/100, rowGap reduced by 1px).
  - **End Match? screen** — already widened earlier in this session; YES/NO no longer touch the hint text.

  **v1.1.2 refactor (2026-05-06, this session):**
  - **Responsive layout everywhere** — `SetupView`, `MainView`, `ConfirmEndView`, `PostMatchView` now compute all y-positions from `dc.getHeight()` percentages and `dc.getFontHeight()` rather than hardcoded pixels. All text uses `TEXT_JUSTIFY_VCENTER` so y-coordinates represent the *centre* of each element (stable across font sizes).
  - **View-by-reference pattern** — `SetupDelegate`, `MainDelegate`, `PostMatchDelegate` now receive their View at `initialize()` time instead of calling `Ui.getCurrentView()[0]`. This is the safe pattern in API 6.0+. `App.mc` and `MatchPersistence.mc` updated to construct delegates with view references.
  - **`ConfirmEndDelegate`** uses `Ui.getCurrentView()` (no `[0]`) plus `instanceof` check for safety. Button bounds (`yesY`, `yesH`, `noY`, `noH`) now stored on the view and read by the delegate instead of being hardcoded.
  - **Side effect** — this is the layout-responsive refactor that was scheduled for v1.2. Brought forward to v1.1.2 because it was the root cause of the real-watch failure. Multi-device support in v1.2 is now much easier as a result.
  - Build target unchanged: still vivoactive6 only. AppID unchanged: `a4302e08-340f-4a11-8970-1cb44e7ab34f`. Upload as a *new version* of the existing public app (not a new app) — no new appID needed for version updates.
- **2026-05-06:** 🎉 **MatchMind v1.1.1 APPROVED by Garmin.** Status went from "Pending review" to "Approved" in less than 24 hours — well inside the 3-day SLA. App is now publicly listed on the Garmin Connect IQ Store and installable by anyone with a Vivoactive 6. Public install URL: `https://apps.garmin.com/apps/a4302e08-340f-4a11-8970-1cb44e7ab34f`.
- **2026-05-05 #3:** v1.1.1 submitted as Public + roadmap captured:
  - Built `Tennistracker.iq` v1.1.1 successfully (warnings only, no errors).
  - Submitted as **Public** (Beta App checkbox UNCHECKED). Listed under Sports category, no subcategory (Sports has none on CIQ Store).
  - Public contact email: `sportsmanagementjb+matchmind@gmail.com` (Gmail "+" alias — routes to `sportsmanagementjb@gmail.com` inbox automatically, keeps personal email private).
  - Monetization: No (free launch). Companion App: none. Hardware: none. ANT+ profiles: none. Privacy data collection: No. App Migration: No (hardcoded layout — risky to auto-enable on new devices).
  - Confirmation page showed "preview mode... up to 3 days" notice. No more BETA banner — confirmed app is in actual review queue this time.
  - Roadmap captured for v1.2 (multi-device) and v1.5/v2.0 (monetization). Free for now, paid features only after gathering real user feedback.
- **2026-05-05 #2:** Beta status diagnosis + decision to go public:
  - **Discovery:** Garmin developer forum + the in-page notice on the MatchMind app page confirmed that Beta (unlisted) apps **never enter the review queue**. Status is permanently Pending — by design. Beta apps are installable only by the developer's own Garmin account.
  - **Blocker:** Jo's watch is paired to a different Garmin account (`sportsmanagementjb@gmail.com`) than the dev account (`josina.md.bernardes@gmail.com`). Beta therefore can't reach her watch. Beta apps also have no tester-invite mechanism in Garmin's CIQ Store.
  - **Decision:** Drop the beta path. Submit a fresh **Public** upload for full Garmin review. Vivoactive 6 only for now — multi-device deferred to v1.2.
  - **Required by Garmin:** new appID in `manifest.xml`. Generated `a4302e08-340f-4a11-8970-1cb44e7ab34f` and replaced the old beta appID. Build target stays `vivoactive6`.
  - **Old beta app:** kept on developer dashboard for now (status = Pending forever, not actively harmful). Can be removed later via the red Remove button on apps.garmin.com.
- **2026-05-05:** Pre-approval code audit (Garmin store still pending v1.1.0 review):
  - **Context:** v1.1.0 submitted 2026-04-24, still Pending after 11 days. Code audit performed to find any reviewer-visible bugs.
  - **BUG FIX — Resume prompt unresponsive on real watch:** `ResumePromptDelegate.onTap()` hardcoded `h = 450` to compute YES/NO tap zones, but Vivoactive 6 is **390×390**. Buttons drawn relative to `dc.getHeight()` (≈205), tap zone calculated at 235 — taps missed the buttons entirely on real device (worked in simulator only because of how the sim handles touch). Fixed by reading `Sys.getDeviceSettings().screenWidth/screenHeight` instead of hardcoding. Added 4px hit-zone padding for finger reach.
  - **BUG FIX — Overlapping tap zones in ConfirmEndDelegate:** YES zone was 142–214 and NO was 215–280. A tap at exactly y=215 was ambiguous. Adjusted to YES 142–213 / NO 216–280 (disjoint, with a 2px gap that matches the visual gap between the buttons).
  - **No-fix items reviewed:** manifest permissions all justified (Fit, FitContributor, Sensor → all used in code); FIT recording (SPORT_TENNIS / SUB_SPORT_MATCH) implemented correctly; SVG launcher icon valid; no naming/trademark red flags. The dead `menus/menu.xml` (Item 1/Item 2 from IDE template) is unused but left in place — Garmin reviewers don't flag unused template resources, and removing it risks breaking other auto-generated references.
  - **Most likely reason for delay:** review queue. Garmin beta/unlisted reviews routinely take 10–21 days, especially after a re-submission.
