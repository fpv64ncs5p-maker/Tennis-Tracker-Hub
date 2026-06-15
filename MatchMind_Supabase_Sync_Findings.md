# MatchMind — Supabase Sync Investigation
**Date:** 12 June 2026  
**Version submitted:** v1.4.6

---

## ⚠️ Corrections (afternoon session, 2026-06-12)

1. **The versionCode theory (finding 4) was wrong.** The sed edit landed in the monorepo manifest (`Tennis-Tracker-Hub/apps/garmin/`), which is never built — `package.sh` builds from the iCloud folder. The submitted v1.4.6 `.iq` was inspected and contains NO versionCode, yet the store accepted it and the update reached the watch. `versionCode` is not part of the CIQ manifest schema; updates work without it.
2. **v1.4.6 confirmed installed on watch; sync still fails silently.** Test matches save to Garmin Connect (so watch↔phone link works) but Supabase API Gateway logs show zero requests to `/rest/v1/matches` from the watch.
3. **Supabase side is proven working.** A curl POST with the same URL, anon key, headers, and payload shape returned 201 and inserted a row. Key, RLS, payload shape, and project (not paused) are all fine.
4. **Next step executed: Step 3 (visible error indicator) → v1.4.7.** New `SyncStatus.mc`; status shown in PostMatchView + SetupView. Also: `Prefer: return=minimal` → `return=representation`, because an empty 201 body + JSON responseType yields CIQ -400, which would make success look like failure.
5. **The -200 claim in finding 1 is doubtful:** -200 is `INVALID_HTTP_HEADER_FIELDS_IN_REQUEST`, not a "no internet" artifact. The simulator can use the Mac's connection.

## ✅ ROOT CAUSE FOUND & FIXED (v1.4.7, 2026-06-12)

The v1.4.7 sync indicator showed `SYNC ERR -200` in the simulator — and -200 is a **local validation error**: the request never leaves the device.

**The bug:** `"Content-Type" => "application/json"` as a plain string. Connect IQ validates request headers locally and only accepts a `Communications.REQUEST_CONTENT_TYPE_*` enum constant for Content-Type. An arbitrary string → -200, silently, on simulator AND real watch, in every version since the sync was first built (v1.2.0). The "sim always returns -200" belief masked it the whole time.

**The fix (SupabaseSync.mc):**
```monkeyc
"Content-Type" => Comm.REQUEST_CONTENT_TYPE_JSON,
```

**Verified:** simulator match → `SYNC OK` (green) → rows in `matches` table, including the previously stuck payload delivered by the startup retry.

**Remaining:** submit v1.4.7 to the store, then confirm once on the real watch. Sim test rows (ids 5, 6 + any later ones) should be deleted from `matches` before the Tennis tab goes live.

---

## What We Found

### 1. The simulator -200 is normal and always will be
The IQ Simulator has no internet access. Every `makeWebRequest` call returns `-200` in the simulator. This only confirms the code *path* runs — it proves nothing about real-watch connectivity. The only valid test is the real watch.

### 2. The code is correct
All three key files were reviewed (`SupabaseSync.mc`, `TennisActivityManager.mc`, `App.mc`) and found to be well-structured with no bugs:
- POST targets `/rest/v1/matches` ✅
- Headers include `apikey` and `Authorization` ✅
- Payload has no null values (fixed in v1.4.5) ✅
- Three upload paths exist: `earlyUpload()` → `stopSession()` → startup retry ✅
- GC anchoring prevents the callback from being collected mid-flight ✅

### 3. The `matches` table was empty — but for the right reason
The 51 API Gateway POSTs visible in Supabase logs were all going to `user_data` (Training Hub), not `matches`. The Garmin app had never successfully written to `matches` on the real watch due to successive payload bugs in v1.4.3–1.4.5.

### 4. The manifest had no versionCode
The `manifest.xml` had no `versionCode` attribute at all. Without it, the ConnectIQ store cannot determine whether a submitted build is newer than what's on the watch — so updates may never actually reach the device. This was the likely reason previous fixes weren't being tested on the real hardware.

### 5. Payload bugs across v1.4.3–1.4.5
| Version | Bug | Effect |
|---|---|---|
| v1.4.3 | `set_scores` array in payload | `makeWebRequest` silently blocked |
| v1.4.4 | Null values in Dictionary | CIQ JSON serializer fails silently |
| v1.4.5 | Boolean type mismatch | Same silent failure |

All three bugs caused `makeWebRequest` to never fire — not even attempt the HTTP call.

---

## What We Did

1. Reviewed all Supabase logs — confirmed 200s are from Training Hub, not Garmin
2. Confirmed `matches` table is empty and `user_data` has only Training Hub data
3. Read and verified `SupabaseSync.mc`, `TennisActivityManager.mc`, `App.mc`
4. Identified missing `versionCode` in `manifest.xml`
5. Added `versionCode="145"` via `sed`, then bumped to `146` when portal rejected 1.4.5 as duplicate
6. Rebuilt with `package.sh` → `BUILD SUCCESSFUL`, `1 OUT OF 1 DEVICES BUILT`
7. Submitted `bin/Tennistracker.iq` to ConnectIQ portal as **v1.4.6**

---

## How to Test Once Approved (~2 hours)

1. Ensure **Garmin Connect is open on your phone** before starting
2. Open MatchMind on the watch and play a match (or a short test)
3. The moment the last point is scored, `earlyUpload()` fires
4. Watch the **`matches` table** in Supabase dashboard for a new row
5. Row should appear within seconds of match end

---

## If It Still Doesn't Work — Next Steps

### Step 1 — Confirm the update installed
On the watch, check the app version (Settings → About, or via Garmin Connect app). It should show **1.4.6**. If it still shows an older version, the store update hasn't reached the watch yet — wait longer or force a sync in Garmin Connect.

### Step 2 — Check PostgREST timeout errors
Supabase logs showed repeated `"Warp server error: Thread killed by timeout manager"` on the PostgREST layer. This is a known free-tier cold-start issue. If the project has been idle, the first request hits a spinning-up server and times out.  
**Fix:** Go to Supabase dashboard → Settings → General → disable "Pause project when inactive". Or manually visit the Supabase dashboard before testing to wake the project.

### Step 3 — Add a visible error indicator on the watch
Currently failed uploads are only logged via `Sys.println` (invisible on the real watch). Add a subtle on-screen indicator in `PostMatchView` showing upload status (✅ / ❌). This would immediately confirm whether `onResponse()` is firing and what code it receives.

### Step 4 — Test the startup retry
If `earlyUpload()` fires but the phone isn't connected, the payload is saved to `MatchPersistence`. On next app open, `App.mc` retries after a 2-second delay. To test this path: play a match with phone disconnected, then open the app again with phone connected and watch for a row in `matches`.

### Step 5 — Check RLS policies on `matches` table
The Supabase dashboard shows **3 RLS policies** on `matches`. If the anon key doesn't satisfy any policy for INSERT, the request will return `401` or `403` (not a payload issue). Verify the policies allow anon inserts, or temporarily disable RLS on `matches` to isolate.

### Step 6 — If all else fails: direct sideload test
Use `run.sh` to sideload directly to the watch (bypassing the store) and test connectivity immediately without waiting for approval cycles. This is the fastest debug loop for real-watch HTTP issues.

---

## Key Facts for Future Sessions

| Item | Value |
|---|---|
| Supabase project URL | `https://pmzzmvzbgeonjnbfreze.supabase.co` |
| Garmin target table | `matches` |
| Training Hub table | `user_data` |
| App UUID | `a4302e08-340f-4a11-8970-1cb44e7ab34f` |
| Current versionCode | `146` (v1.4.6) |
| Upload trigger | `earlyUpload()` at last point scored |
| Retry mechanism | `App.mc` retries on startup if payload saved in `MatchPersistence` |
