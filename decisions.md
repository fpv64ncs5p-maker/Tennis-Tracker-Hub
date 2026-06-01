# Decisions & Bug Fixes

## Training Hub — Supabase Sync Migration — 2026-05-27

### Decision: Replace GitHub Gist sync with Supabase

**Problem:**
GitHub Gist sync was fragile — required a Personal Access Token, had race conditions, and caused repeated data loss across devices (phone vs laptop out of sync). Token management was a source of friction and confusion.

**Solution:**
Replaced the entire Gist sync section with Supabase-backed sync. No token needed — uses the same anon key already in the file (same project as the Tennis tab). Architecture is identical: localStorage-first, single JSON blob, timestamp-based merge (cloud wins if newer, local pushes if newer, deferred 3s on every write).

**Supabase table:** `user_data` (pre-existing key-value store schema)
- `key TEXT` — row identifier, fixed value `'jo'`
- `value JSONB` — stores `{payload: {...all 14 training data keys...}, last_modified: ts}`
- `updated_at TIMESTAMPTZ` — auto-managed
- RLS + GRANT already configured on this table

**SQL to run:** `supabase-migration.sql` in repo root.

**Data import:** Use "Restore Backup" button to reload JSON backup into localStorage, then "Push to Cloud" to seed Supabase.

**Files changed:**
- `apps/training-hub/index.html` (+ root `index.html` + PROJ0004 copy)
  - Removed: `_ghHeaders`, `_GIST_FILE`, `_ghToken`, `saveGHToken`, `clearGHToken`, `_getGistId`, `_pushToGist`
  - Added: `_sbSyncHeaders`, `_pushToSupabase`, `_pullFromSupabase`
  - Updated: `syncFromCloud`, `pushToCloud`, `pullFromCloud`, `_syncKeyToCloud`, `_sbInit`
  - Moved `_SB_URL`/`_SB_KEY` to before sync section (shared by sync + Tennis tab)
  - Removed GitHub token setup UI from Home screen
  - `renderHome()` simplified — no token check, sync always active

---

## v1.3.10 — 2026-05-28

### Fix: makeWebRequest fails during getInitialView() + GC kills callback

**Problem 1 — Too-early web request:**
The startup retry in v1.3.9 called `makeWebRequest` inside `getInitialView()`. This fires before the Communications layer is ready — in the simulator it returns -200; on a real watch it silently drops the request. The `supabase_payload` key was never cleared, so every app open attempted and failed the retry forever.

**Problem 2 — Garbage collection kills the callback:**
Even when `makeWebRequest` fires at the right time, if the `SupabaseSync` instance (or the `TennisActivityManager` holding it) is not anchored to a long-lived object, the Monkey C GC can collect it before `onResponse()` fires. The HTTP request completes but the callback is gone — Supabase gets the POST but the app never clears the `supabase_payload` key.

**Fix 1 — Deferred retry via Timer:**
Moved the pending-upload retry from `getInitialView()` to `onStart()`. A 2-second `Timer.Timer` (`_retryTimer`) defers `retryPendingUpload()` until the app is fully initialised and the Communications layer is live.

**Fix 2 — GC anchor on TennisApp:**
Added `_matchSync` field to `TennisApp`. After `_supabaseSync.uploadMatch(engine, self)` fires in both `earlyUpload()` and `stopSession()`, the `TennisActivityManager` instance is anchored: `Application.getApp()._matchSync = self`. Released to `null` in `SupabaseSync.onResponse()` on success (along with `_startupSync`).

**Files changed:**
- `apps/garmin/source/App.mc` — moved retry to `onStart()` + timer; added `_matchSync` and `_retryTimer` fields
- `apps/garmin/source/TennisActivityManager.mc` — added `using Toybox.Application;`; added `Application.getApp()._matchSync = self` in `earlyUpload()` and `stopSession()`
- `apps/garmin/source/SupabaseSync.mc` — added `using Toybox.Application;`; added GC anchor release in `onResponse()` on success

---

## v1.3.9 — 2026-05-27

### Fix: Wrong Supabase anon key + startup retry crash

**Problem 1 — Wrong key format:**
`Secrets.mc` had `sb_publishable_...` format key (new Supabase SDK format) instead of the JWT token required by the REST API. The Garmin app calls Supabase directly via `makeWebRequest` (raw REST, no SDK), so it needs the `eyJ...` JWT anon key. All upload attempts silently went nowhere — Supabase API logs showed zero requests to `/rest/v1/matches`.

**Fix:** Updated `SUPABASE_ANON_KEY` in `Secrets.mc` to the JWT token (same key confirmed working in Training Hub).

**Problem 2 — Startup retry crash:**
When a stale `supabase_payload` was in Storage (from a previous session with the wrong key), the startup retry in `App.mc` crashed with `Symbol Not Found Error`. The crash prevented the app from launching.

**Fix:** Wrapped the entire startup retry block in `try/catch (Lang.Exception)`. If restore or upload fails for any reason, the bad payload is cleared and the app continues normally.

**Files changed:**
- `Secrets.mc` — `SUPABASE_ANON_KEY` updated to JWT format (gitignored, not committed)
- `apps/garmin/source/App.mc` — added `using Toybox.Lang;`, wrapped startup retry in try/catch

---

## v1.3.8 — 2026-05-27

### Bug: Supabase retry silently failing after normal match end

**Problem:**
v1.3.7's pending upload retry used `tennis_match_state` (resume state) to reconstruct the engine on next app open. But `finishAndExit()` calls `clearState()`, which deletes that key. When the match ends normally (user taps summary screen → exits), the state is gone before the next open. App.mc found no state to upload from and just cleared the pending flag — silent failure, no retry.

**Fix:**
Save the Supabase payload to a **separate** Storage key (`supabase_payload`) at the moment the upload is attempted (in `earlyUpload()` and `stopSession()`). This key is never touched by `clearState()`. It is only cleared when `SupabaseSync.onResponse()` receives a 200/201/204 success. On next app open, `App.mc` checks this key instead of the resume state — so the retry works regardless of how the match ended.

**Files changed:**
- `apps/garmin/source/MatchPersistence.mc` — replaced `PENDING_UPLOAD_KEY` with `SUPABASE_PAYLOAD_KEY`; new functions: `saveSupabasePayload()`, `hasSupabasePayload()`, `loadSupabasePayload()`, `clearSupabasePayload()`
- `apps/garmin/source/TennisActivityManager.mc` — `earlyUpload()` and `stopSession()` call `saveSupabasePayload()` before firing the POST
- `apps/garmin/source/SupabaseSync.mc` — `onResponse()` calls `clearSupabasePayload()` on success
- `apps/garmin/source/App.mc` — startup retry reads from `supabase_payload` key directly

---

## v1.3.7 — 2026-05-27

### Feature: Pending upload — no match data ever lost

**Problem:**
Even with earlyUpload (v1.3.6), a Supabase POST can fail or be abandoned if: (a) the request didn't complete before the OS killed the app, (b) the phone had no internet at that moment, or (c) the user triggered a mid-match exit via the Garmin native activity dialog (physical button → Save). In all these cases, the match data exists in watch Storage but never reached Supabase.

**Fix — "pending upload" pattern:**
1. Every `MatchPersistence.saveState()` call now also sets a `pending_upload` flag in Storage.
2. When `SupabaseSync.onResponse()` receives a 200/201/204, it calls `MatchPersistence.clearPendingUpload()`.
3. On app startup, `App.getInitialView()` checks `hasPendingUpload()`. If set and match state exists, it reconstructs the engine from Storage and fires a fresh upload silently in the background — before showing any screen.
4. If the flag is set but state is gone (normal exit completed): just clear the flag.

**Bonus fix in same release:**
`getInitialView()` now skips the "Resume match?" prompt for completed matches (`matchOver = true` in saved state) — an edge case where the app exited after the last point but before `clearState()` ran.

**Files changed:**
- `apps/garmin/source/MatchPersistence.mc` — added `PENDING_UPLOAD_KEY`, `hasPendingUpload()`, `clearPendingUpload()`; `saveState()` sets the flag on every call
- `apps/garmin/source/SupabaseSync.mc` — `onResponse()` calls `clearPendingUpload()` on success
- `apps/garmin/source/App.mc` — `getInitialView()` retries pending upload on startup; skips resume prompt for completed matches

---

## v1.3.6 — 2026-05-27

### Bug: Physical button exits app before PostMatchView is ever shown

**Problem:**
v1.3.5 fixed the Supabase sync for the natural match-end flow by firing `stopSession()` in `PostMatchDelegate.initialize()`. But there is a third path: pressing the upper physical button on the watch while on the "YOU WIN!" screen. The code routes this through `showConfirm()` (MatchMenu), but the Garmin OS intercepts the physical button during an active ActivityRecording session and exits the app directly — before PostMatchView or MatchMenu is ever reached. `uploadMatch()` never fires.

**Fix:**
Fire `earlyUpload()` the instant the last point is scored — inside `MainDelegate.onTap()`, right after `engine.handleInput()` returns, by detecting the `!prevMatchOver → engine.matchOver` transition. This is completely decoupled from any subsequent user action. By the time the OS can kill the app, the HTTP request is already in flight via Bluetooth.

`_uploadFired` flag in `TennisActivityManager` prevents a double-POST if `stopSession()` is also called later via the normal SAVE path.

**Files changed:**
- `apps/garmin/source/TennisActivityManager.mc` — added `_uploadFired` flag + `earlyUpload()` method; `stopSession()` skips upload if already fired
- `apps/garmin/source/MainView.mc` — `MainDelegate.onTap()` calls `manager.earlyUpload(engine)` on the `matchOver` transition

---

## v1.3.5 — 2026-05-25

### Bug: Supabase sync still failing for natural match-end flow

**Problem:**
v1.3.4 fixed the sync for matches ended via MatchMenu → SAVE, but natural match-end (all points scored → "YOU WIN!" screen) bypasses MatchMenu entirely and goes directly to PostMatchView. The upload still fired in `finishAndExit()` right before 3× `popView()`, too late for the request to complete.

**Fix:**
Moved `stopSession()` to `PostMatchDelegate.initialize()` — fires the moment PostMatchView is created, giving the full time the user spends on the summary screen for the HTTP request to reach Supabase. `finishAndExit()` guard (`isActive()`) prevents double-calls.

**Files changed:**
- `apps/garmin/source/PostMatchView.mc`

---

## v1.3.4 — 2026-05-25

### Bug: Supabase sync never reaching server — upload killed on app exit

**Problem:**
Matches saved to on-watch history correctly, but the Supabase `matches` table remained empty after every match. RLS policies (anon INSERT + SELECT) were confirmed correct. The issue was timing: `stopSession()` (which calls `uploadMatch()` / `makeWebRequest()`) was fired inside `finishAndExit()`, immediately followed by 3x `popView()`. On a real watch the async HTTP request travels via Bluetooth → paired phone → internet, which takes longer than the milliseconds before the app exits. The request was being abandoned in transit.

**Fix:**
Moved `stopSession()` to the SAVE path in `MatchMenuDelegate.executeOption()`, so the upload fires as soon as the user taps SAVE — while PostMatchView is still on screen. The user typically spends 5–15 seconds on the summary, giving the HTTP request plenty of time to complete. `finishAndExit()` already guards against double-calling via `manager.isActive()`, so no other changes needed.

**Files changed:**
- `apps/garmin/source/MatchMenu.mc`

---

## v1.2.3 — 2026-05-25

### Bug: Save/Discard unresponsive at match end — history not saved

**Problem:**
When a match ended naturally (final point scored), the app showed a "YOU WIN!" / "MATCH OVER" screen but buttons were unresponsive, and match history was never saved.

**Root causes:**
1. `PostMatchDelegate` had no `onTap()` handler — tapping the summary screen did nothing.
2. `MainDelegate.onBack()` on the match-over screen silently exited the app without calling `MatchHistory.saveMatch()`.
3. `manager.stopSession()` was called immediately at match end, triggering the Garmin activity overlay (blue triangle) which blocked all further input — both in the simulator and potentially on the real watch.

**Fix:**
- Removed early `stopSession()` call from `MainDelegate.onTap()` — session stays active until user explicitly acts.
- Any button press on the match-over screen now opens the **MatchMenu** (same SAVE/LATER/DISCARD flow as mid-game), via `showConfirm()`.
- Added `onTap()` to `PostMatchDelegate` so tapping the summary screen calls `finishAndExit()`.
- Guarded `stopSession()` in `finishAndExit()` with `manager.isActive()` to prevent double calls.
- Updated match-over hint text from "Tap for summary" to "Tap to save or discard".

**Files changed:**
- `apps/garmin/source/MainView.mc`
- `apps/garmin/source/PostMatchView.mc`

---

## General Decisions

### Architecture
- Monorepo with two independently deployed apps (Garmin + web dashboard).
- Supabase is the single source of truth for match data — Garmin app writes, Training Hub reads.
- `Secrets.mc` is never committed to git (API keys for Garmin app).

### Simulator vs Real Watch
- The CIQ simulator shows a blue triangle overlay when an activity session is stopped — this is a simulator artifact and does not reflect real watch behaviour.
- Always test history-saving and activity recording on the real watch before shipping.

---

## Garmin App — Key Technical Decisions (from V1 log)

### Store packaging: always use `-e`, never `-r`
Use `monkeyc -e` (export) for all store submissions. `-r` (release) produces a `.iq` that the Garmin Developer Portal rejects with "error processing manifest file". `package.sh` is already updated with the correct flag.

### Garmin Connect filters developer fields universally
All FIT developer fields are physically present in the file (confirmed via Python `fitparse`) but Garmin Connect suppresses them server-side regardless of sport type. This is not a Tennis-specific limitation. Switching to `SPORT_GENERIC` was tested in v1.1.7–1.1.8 and gained nothing — reverted to `SPORT_TENNIS` in v1.1.9 to keep racket icon + "All Racket Sports" aggregation.

### Sport type: `SPORT_TENNIS / SUB_SPORT_MATCH`
Kept permanently after SPORT_GENERIC experiment. Reason: tennis icon in Garmin Connect, racket-sport grouping, and Garmin Connect filters developer fields universally anyway.

### FIT developer fields: seed with `setData(0)` before session start
Without an initial seed, Garmin Connect strips the Connect IQ section from the activity entirely. All developer fields must receive `setData(0)` before `_session.start()` is called.

### Field names: use human-readable strings
Short codes like `p_pts` are filtered server-side by Garmin's Tennis template. Use full names like "Points won".

### Lap announcements removed
`_session.addLap()` was removed from `markSetEnd()`. The Garmin OS announces laps out loud (beep + vibration), which is disruptive mid-match.

### Supabase project: Training Hub (`pmzzmvzbgeonjnbfreze`)
All MatchMind match data goes to the Training Hub Supabase project. Consolidates all training data in one place. Matches table has 27 columns (engine stats + nullable `opponent_name`, `location`, `notes`). RLS: anon INSERT (watch) + anon SELECT (web).

### CIQ Storage: flat String-keyed dict, primitives only
Symbol keys (`:name`) and nested dicts crash CIQ Storage. All storage uses String keys with prefix convention (e.g. `hN_won` for match history). Arrays of dicts are stored as parallel arrays.

### Vivoactive 6: no USB mass storage
Newer Garmin devices dropped USB drive mode — install only via Connect IQ Store.

### App distribution: Public (not beta)
Beta apps never enter the review queue. Beta and user accounts are separate — beta can't reach Jo's watch.

---

## Training Hub — Key Technical Decisions (from V1 log)

### Single-file architecture
Everything (HTML, CSS, JS) in one `index.html` file. No external CDN dependencies, no build step. Mobile-first (700px max width), offline-first, light mode only.

### Sync: GitHub Gist API, not Supabase
**⚠️ Critical for Tennis tab integration.** Supabase DNS (`pmzzmvzbgeonjnbfreze.supabase.co`) failed consistently from JavaScript on Chrome and Safari (`ERR_NAME_NOT_RESOLVED`), likely due to mobile network DNS filtering or Safari ITP. Switched to GitHub Gist API (`api.github.com`) which works reliably on all tested networks.

This means the Tennis tab **cannot** use the Supabase JS SDK the same way as other Training Hub data. The DNS issue must be investigated before building the Tennis tab. Possible mitigations: test if the DNS issue is still present on current network/browser, use a proxy, or fetch via a GitHub Action intermediary.

### GitHub token storage
GitHub Personal Access Token (PAT) with `gist` scope stored in localStorage (`_gh_token`). Never hardcoded in source. User pastes it once via the app UI.

### Sync strategy: offline-first, local wins
localStorage is primary. On startup: if local has data → push to Gist. If local is empty → pull from Gist. Every `DB.set()` triggers a debounced push (3s delay). Push has a mutex (`_pushInProgress`) to prevent race conditions.

### Tennis accent colour
`#a78bfa` (lavender) — matches the pattern of other modules (Gym: `#15803d`, Climbing: `#1d4ed8`, Rehab: `#ea580c`, Planner: `#6d28d9`).

### No CDN — no external scripts
Training Hub loads zero external resources. If the Tennis tab needs Supabase JS SDK, it must either be inlined or loaded via `<script>` tag within the single file. Alternatively, use raw `fetch()` calls to the Supabase REST API directly (no SDK needed).
