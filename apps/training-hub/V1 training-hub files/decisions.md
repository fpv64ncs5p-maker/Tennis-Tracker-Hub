# Training Hub — Decisions Log

All key product and design decisions made during development, in roughly chronological order.

---

## App Architecture

- **Single-file HTML app** — everything (HTML, CSS, JS) lives in one `training-hub.html` file with no external dependencies or CDN calls.
- **localStorage only** — no backend, no sync, no login. All data persists in the browser.
- **Mobile-first, 700 px cap** — designed for phone use first; content centred and capped on desktop.

---

## Visual Design

- **Light colour mode** — switched from dark/heavy palette to a light theme. All colours defined as CSS custom properties on `:root` so a dark toggle can be added later.
- **Compact spacing** — tighter padding, smaller font sizes for labels, reduced card margins to keep more content visible on small screens.
- **Accent colours per module** — Gym: `#15803d` (green) · Climbing: `#1d4ed8` (blue) · Rehab: `#ea580c` (orange) · Planner: `#6d28d9` (purple). Colors made more saturated in the Apr 2026 bold redesign.
- **Bold & sporty redesign (Apr 2026)** — CSS-only visual refresh at Jo's request:
  - Page headers enlarged to 22px / weight-800 with tight letter-spacing
  - Card module accents changed from 2px top border → 4px left border (bolder stripe)
  - `stat-val` numbers enlarged to 28px / weight-800 for at-a-glance impact
  - Bottom nav upgraded: no top border → bottom-up shadow, wider pill active indicator (border-radius 22px, 4px 16px padding)
  - Cards and modals: stronger shadow (`0 4px 20px …`), slightly larger radius (14px / 9px)
  - Toast redesigned as dark pill (text on `--text` bg, border-radius 22px) matching modern app conventions
  - All label/title font-weights bumped to 700–800 throughout
  - Input borders 1.5px for more definition
  - Module colors deepened for better contrast (gym `#15803d`, climb `#1d4ed8`, rehab `#ea580c`, plan `#6d28d9`)

---

## Gym Module

- **Body metrics expanded** — added Height (cm), Body Fat (%), and Muscle Mass (kg) alongside body weight on the Log Session form. Height persists separately in `gym_height`; the rest are saved per session.
- **Templates feature** — sessions can be saved as reusable templates (⭐ Save Template from History detail). Templates auto-named by muscle area + date. Templates section appears at the top of Build Session.
- **Clear Session button** — red button to wipe all exercises from the current session without saving. Requires confirmation dialog.
- **Auto-scroll after adding exercise** — view scrolls to the Add Exercise button after each addition so the next exercise is immediately reachable.
- **Per-exercise editing in History** — every exercise in a saved session has an ✏️ edit and 🗑 delete button. Edit modal supports strength, cardio, and time-based exercise types.
- **Modal ✕ close buttons** — all modals have a visible ✕ button in the top-right corner, in addition to backdrop tap-to-close.

---

## Fingerboard Module

- **Separate sub-tab inside Gym** (Option B chosen over putting it in Climbing or as a top-level tab) — accessible as the 5th segment in the Gym tab.
- **Fully independent storage** — `fb_sessions` and `fb_templates` are completely separate from `gym_sessions` and `gym_templates`.
- **Own exercise library** — exercises with `cat:"Fingerboard"` appear only in the FB Add Exercise modal, never in the Gym modal or Build Session chips.
- **Fingers category kept for Gym** — `Grips w/ Machine` stays as `cat:"Fingers"` in the Gym library (machine-based grip training). Only hang/board exercises were moved to Fingerboard.
- **Fingerboard exercises removed from Gym Build chips** — the Fingerboard and Fingers chips no longer appear in the Gym Build Session category filter (except Rehab).
- **FB can be done on climbing or off-climbing days** — the module is not locked to either; it's simply accessed from the Gym tab whenever needed.

---

## Climbing Module

- **Lattice Assessment inside Pyramid sub-tab** — rather than a new top-level tab or 4th segment, the Pyramid sub-tab was expanded into two stacked sections: (1) Lattice Assessment on top, (2) Grade Pyramid below.
- **Manual entry only for assessments** — historical Lattice data (May 2024, Jan 2026) not pre-seeded; Jo enters assessments herself.
- **Progress arrows on assessment cards** — ↑/↓ arrows auto-appear when 2+ entries exist, comparing each metric to the previous test. Side split arrows are inverted (lower cm = improvement).

---

## Planner Module

- **Multi-session per day** — planner migrated from a single flat activity per day to a `sessions[]` array. Each day can hold multiple sessions, each with its own type, subtype, duration, RPE, and notes.
- **Work days: max 2 sessions** — labelled "Before work" and "After work".
- **Off days: max 3 sessions** — labelled "Morning", "Afternoon", and "Evening".
- **All days use the same 3-slot structure** — work days and off days behave identically: up to 3 sessions (Morning / Afternoon / Evening), added via "+ Add session", removed with ✕. Work days additionally show the 💼 Work hours block as a visual divider in the body.
- **Work day body is a visual timeline** — session[0] ("Morning") renders above the 💼 Work block; sessions[1+] ("After work" / "Evening") render below it. No enforcement — user decides what goes where.
- **Work day header is a visual timeline** — the collapsed day header reads left-to-right as a schedule: morning activity → 💼 work badge → after-work activity (e.g. 💪 Gym · 💼 10:00–18:00 · 🏌️ Golf). Before/after split is derived from sessions[0] vs sessions[1+].
- **Data migration** — existing planner entries with flat `trainingType` fields are automatically migrated to the `sessions[]` structure on first load. Any null placeholders from the old Before/After work structure are cleaned up on load.
- **Week summary counts all sessions** — type chips in the weekly header reflect total sessions across all slots for the week.

---

## Rehab Module

- **Program start date** — a date input at the top of the Rehab tab lets Jo set the program start date. All phase date ranges auto-calculate from this date based on fixed week offsets (Week 1: days 0–6, Weeks 2–3: days 7–20, Weeks 4–5: days 21–34, Weeks 6–8: days 35–55, Weeks 9–12: days 56–83).
- **Per-phase date override** — each phase can have its own start date set independently (e.g. if a phase was paused or restarted). A Reset button restores it to the auto-calculated date. Phase stays open after saving.
- **Editable weights** — all exercise weights are now inline editable inputs (stored in `rehab_data.weights[phaseIdx][exIdx]`), including bodyweight exercises which show a **bw+** prefix with a numeric field for added weight (defaults to 0).

---

## Climbing Module (Log Redesign)

- **Block-based session structure** — climbing log migrated from single route-by-route entry to a block system. Each session can have multiple blocks: 🪨 Routes/Bouldering, 🟫 Board/Moves, 🔁 ARC. Matches Lattice training categories (Bouldering, Power Endurance, Aerobic Base).
- **Routes block: three phases** — Warm-up / Main Session / Cool-down, each with its own entries. Result options: OS, Flash, RP, Repeat, Project (no "Warm-up" result — the phase itself carries that meaning).
- **Batch entry** — grade + result + count (×1–10) added in one tap per phase. Much faster for volume sessions.
- **Climbed down toggle (↕)** — per entry, marks that the route was climbed back down. Doubles the meter count for that entry. Also always counts as a send regardless of result.
- **Board block** — board name selector (Moonboard A/B, Spray wall, Kilter, System wall, Custom) + sets of reps × moves. Totals moves automatically.
- **ARC block** — duration (min) + intensity (Low / Moderate / High).
- **Sends definition** — all results except Project count as sends (OS + Flash + RP + Repeat + climbed-down routes).
- **Pyramid: Projects visible** — Project results now appear in the pyramid as 🔴 X working on the grade tier, and in the stats table under "Work". Disappears once the grade is fully sent. Only OS/Flash/RP count toward pyramid targets.
- **Backward compatibility** — old sessions with `routes[]` array still render correctly in History and Pyramid via `getSessionRoutes()` helper.
- **Edit climbing sessions** — ✏️ Edit Session button in the detail modal loads the session back into the Log tab (pre-filled date, gym, duration, all blocks). Save button becomes "Update Session" and replaces the original. Legacy sessions migrate to block format on edit.

---

## Climbing Session Templates

- **Source** — templates derived from the MyClimbing doc Challenge PDF (stored in `lattice&climb assessments/`), which defines structured boulder sessions per target grade.
- **10 pre-built templates** — Base and Power variants for grades 6a, 6a+, 6b, 6c+, and 7a. Each has prescribed grades for Warm-up, Sets (Main), and Cool-down phases.
- **7a simplified** — only the more advanced variation is included: Base 10x (W.up 6a+/6b) and Power 15x (W.up 6b/6b+). These correspond to a climber already close to the 7a grade.
- **Grade filter UI** — templates section sits above the blocks in the Log tab. Grade chips (6a · 6a+ · 6b · 6c+ · 7a) filter which templates are shown. Defaults to 6c+ (Jo's current training grade).
- **One-tap apply** — tapping Apply pre-fills the entire Routes block (all 3 phases) with prescribed grades, result defaulting to Repeat. Any existing board/ARC blocks are preserved; only the routes block is replaced.
- **Route grouping** — consecutive same-grade routes within a phase are grouped into a single batch entry (e.g. three 6c routes → 6c ×3) for a compact display.

---

## Weekly Planner — Week Totals Widget

- **Approach** — Option B: cross-references actual logged sessions (gym, climb, fingerboard) by date against the current week range. Does not rely on the planner's free-text duration fields.
- **Placement** — collapsible card above the day list (`#planner-week-totals`), rendered fresh on every week navigation.
- **Hides when empty** — if no sessions have been logged for the viewed week, the widget doesn't appear.
- **Metrics shown per sport:**
  - 💪 Gym: session count · total duration · total volume (sets × reps × weight in kg, formatted as tonnes if ≥ 1000 kg)
  - 🧗 Climbing: session count · total duration · route count · meters climbed (wall height × route count)
  - 🤌 Fingerboard: session count · total duration
- **Total training time** — shown in the card header as a quick summary even when collapsed.
- **Collapsible** — toggled via `toggleWeekTotals()`; state preserved in `_weekTotalsOpen` variable.

### Bug fix (March 2026)
- **Root cause** — `renderWeekTotals` was called at the top of `renderPlanner`, before the data migration that converts old flat `trainingType/duration` plan_data entries to the new `sessions[]` format. On the first visit to any pre-migration week, Golf/Tennis/Active sessions from the Planner were invisible (the function was reading unmigrated data).
- **Fix** — moved `renderWeekTotals(currentWeekStart)` to after `DB.savePlan(data)` in `renderPlanner`, ensuring it always reads freshly migrated data. Gym/Climb sessions from their own logs were unaffected (they come from separate localStorage keys).

---

## Macrocycle Tracker (Climbing Tab)

- **Location** — 4th sub-tab inside the Climbing tab (Log / Pyramid / History / Macro), matching the Rehab module pattern.
- **Source data** — based on the Macrocycle sheet in `Lattice training 24_25.xlsx`, which defines a 6-phase 6-month training cycle.
- **6 phases** — Preparation (2–4 wk) · Base (4–12 wk) · Build (4–6 wk) · Taper (1–2 wk) · Peak (1–6 wk) · Deload (1–4 wk).
- **Start-date anchored** — user sets the cycle start date; all phases calculate forwards from there. Peak window auto-calculates and is shown prominently in the overview banner.
- **Default week counts** — Prep 3w · Base 8w · Build 5w · Taper 2w · Peak 4w · Deload 3w. All adjustable via +/− buttons within their allowed range.
- **Per-phase duration control** — ± buttons to adjust each phase's weeks within the allowed range; "reset" link restores default. Stored in `macro_data.phaseWeeks`.
- **"You are here" indicator** — current phase is highlighted with a coloured left border and a badge showing days remaining. A summary banner at the top shows the active phase with its colour.
- **Storage** — `macro_data` in localStorage (`DB.macroData()` / `DB.saveMacro()`), independent from all other modules.

---

## ACSM-Informed Feature Expansion (Apr 2026)

Four new features added to the Gym tab, derived from ACSM Resources for the Personal Trainer (5th Ed):

- **Session Goal field** — dropdown (Strength / Hypertrophy / Power / Endurance / General) on the Gym log form. Saved as `s.goal` per session. Shows FITT-VP hint inline when a goal is selected (% 1RM, reps, sets, rest guidance from ACSM). Restored on session edit.

- **Gym Macrocycle tracker** (`📅 Macro` tab) — 4-phase gym periodization: Hypertrophy → Strength → Power → Deload. Start-date anchored, phases auto-calculated, adjustable ±1 week within allowed range. Data stored in `gym_macro_data`. Current phase highlighted with colour + days-remaining badge. Follows exact same pattern as climbing Macro tab.

- **Gym Assessments** (`📋 Assess` tab) — manual-entry fitness testing log tracking: 1RM (Squat, Bench, Deadlift, Row), Push-up max reps, Sit-and-reach (cm), body weight. Progress arrows (▲/▼/→) comparing each metric to previous assessment. Based on ACSM's recommended assessment sequence. Data stored in `gym_assessments`.

- **Stretch / Mobility log** (`🧘 Stretch` tab) — standalone stretching session logger with: date, duration (min), technique (Static / Dynamic / PNF / SMR / Yoga / Mixed), muscle group chips, notes. History shows this-week count + total minutes with ACSM target banner (≥2 sessions/week). Data stored in `stretch_sessions`.

- **Gym segment** made horizontally scrollable (`overflow-x:auto;flex-wrap:nowrap`) to accommodate 8 tabs. All buttons now use `data-mode` attribute for active state (replacing fragile index-based approach).

- **Gym Assessments rebuilt** (Apr 2026) — replaced ACSM standard benchmarks with Jo's actual exercises. Dynamic exercise list (default + picker from EXERCISES library). Best-set format: `weight × reps` for strength machines, `sec` for timed (Plank), `max reps` for bodyweight, `cm` for flexibility. Default exercises: Leg Press, Hip Abductor, Ext. Quadriceps (Inferior), Pull-up + Weight, Lat Pulldown, Chest Press (Superior), Plank, Russian Sit-ups (Core), Sit-and-reach, Side Split (Flexibility). Macro phase captured at save time. Delta arrows compare each exercise to previous assessment (strength compares weight×reps total; Side Split lower=better). Phase-end nudge appears in macro banner when ≤7 days remain in a phase (tappable → goes to Assess tab).

## Climbing Self-Assessment Module (Apr 2026)

- **New sub-tab** — `📋 Self-Assess` added to Climbing tab, between Macro and Climbing Gym.
- **Source data** — 8 evaluation categories from `Self_assessment22.xlsx`, each with 5 questions scored 1–5 (total /25), plus 5-band interpretation feedback.
- **Categories**: Climbing Experience · Technical Skills · Mental Skills · General Fitness · Climbing-Specific Fitness · Injury Risk · Nutrition · Lifestyle.
- **Wizard flow** — one category per screen, progress bar at top, radio-style answers, Back/Next navigation. All 5 questions must be answered before advancing.
- **Scoring** — colour-coded bands (green 23–25, lime 20–22, amber 15–19, orange 10–14, red 5–9), each with specific feedback text from the original spreadsheet.
- **Summary view** — shows latest assessment with all 8 scores + ▲▼→ deltas vs previous assessment. History list below, tappable for full detail modal.
- **Detail modal** — shows per-question answers + band feedback, with delete option.
- **Storage** — `self_assessments` in localStorage via `DB.selfAssessments()` / `DB.saveSelfAssessment()` / `DB.deleteSelfAssessment()`.

## Climbing Gym Module Restructure (Apr 2026)

- **Renamed**: "Fingers / Fingerboard" → **Climbing Gym** (tab label, toasts, empty states)
- **Exercise library replaced**: Old `cat:"Fingerboard"` exercises removed. New exercises from `Training charts.xlsx` (3 sheets) imported into 6 CG- categories:
  - `CG-Fingers` — Finger Flexors (bouldering, hangboard protocols)
  - `CG-Arms` — Arms & Torso (pull-up variations, lat pulldown)
  - `CG-Antagonist` — Wrist & Forearm Stabilizers
  - `CG-Rotator` — Rotator Cuff & Scapular
  - `CG-Push` — Antagonist Push Muscles
  - `CG-Core` — Climbing-specific Core only (general Core stays in Gym tab)
- **Level field** added to each exercise: `level:"both"` (Beginner + Intermediate) or `level:"intermediate"`
- **Build tab** now groups exercises by category with colour-coded headers and a **All / 🟢 Beginner / 🔶 Intermediate** filter row
- **`FB_EXERCISES`** now filters `EXERCISES` by `e.cat.startsWith('CG-')`

## Tab Reorganisation (Apr 2026)

- **Gym tab — Macro moved first** — `📅 Macro` is now the first seg-btn (before Log). Gives phase context before logging. Log remains the default active panel on tab open.
- **Fingerboard moved to Climbing tab** — `🪨 Finger` seg-btn removed from Gym, added as 5th button in Climbing tab. `climbMode('finger')` shows `#gym-finger` panel and calls `fbMode('log')`. `gymMode()` always hides `#gym-finger`. Storage and logic unchanged — purely a UI/navigation move.

## Phase-Aware Suggest & Generate Plan (Apr 2026)

- **`suggestWeight()` rewritten** — now uses a 3-tier lookup:
  1. Sessions logged **within the current gym macro phase** (date range from `gymMacroDateRanges`)
  2. All-time sessions (fallback if no phase match)
  3. Seeded `WEIGHT_REF` data (final fallback)
  - Scaling: if the matched exercise has both weight + intensity saved, it scales to the requested intensity. If intensity is missing, it returns the raw last-logged weight.
  - Sessions are iterated newest-first (since `DB.saveGym` unshifts), so the most recent match is always used.

- **`generatePlan()` rewritten** — now frequency-sorts the exercise pool before round-robin selection:
  - Builds a frequency map (exercise name → count) from sessions in the current macro phase
  - If fewer than 3 phase sessions exist, blends in all-time counts at 30% weight to bootstrap
  - Each category's list is sorted by frequency before round-robin, so your most-used exercises fill the plan first
  - Plan card shows a data source label ("Based on N sessions this phase" or "Based on all-time history") and a usage count badge (×N) per exercise

## App Review & Safety Fixes (Apr 12, 2026)

- **Full UX + Technical review completed** — see `Training Hub - App Review.md` for detailed findings.

### Implemented fixes:

- **JSON export/import** — `exportAllData()` downloads all localStorage keys as a timestamped JSON file. `importAllData()` restores from a backup file with version check and confirmation. Both buttons on Home screen under "Data" section.
- **Unsaved-work protection** — `markDirty(module)` / `clearDirty()` / `isDirty()` system. `switchTab()` now warns before navigating away from unsaved gym, climbing, or fingerboard sessions. `beforeunload` handler also guards browser tab/window closes.
- **HTML escaping** — `esc()` utility escapes `& < > " '` in user-entered text. Applied to all `.notes` fields in template literals and user-entered template names. Prevents XSS from notes containing HTML characters.
- **Storage monitoring** — Home screen shows localStorage usage (KB and % of 5MB limit) with red warning when >80% full.
- **Data keys tracked** — `DATA_KEYS` constant lists all 14 localStorage keys for consistent export/import coverage.

---

## Medium-Priority Improvements (April 2026)

### History pagination

- All three history views (Gym, Climbing, Fingerboard) now paginate at 20 sessions by default.
- "Load more (N older)" button appends the next 20. Total session count shown at top.
- Pagination counters (`_gymHistoryShown`, `_climbHistoryShown`, `_fbHistoryShown`) reset to `HISTORY_PAGE_SIZE` when entering the respective history mode, so users always start from the most recent.

### Lightweight undo

- `pushUndo(label, restoreFn)` captures a closure that can reverse the last delete action.
- `showUndoToast()` shows a 5-second toast with an "Undo" button. `executeUndo()` runs the restore function.
- Wired into 12 delete/remove functions:
  - **In-session (no confirm, instant undo):** `removeExercise`, `removeRouteEntry`, `removeBoardSet`, `removeRouteFromSection`, `removeRouteFromBlock`, `removeFBExercise`
  - **DB-persisted (confirm + undo):** `deleteGymAssessmentEntry`, `deleteStretchEntry`, `deleteAssessment` (climb), `deleteSA` (self-assessment), `deleteFBTemplate`, `deleteFBHistoryEx`
- DB-persisted deletes keep the `confirm()` dialog as a first guard, then offer undo as a second chance. In-session deletes skip confirm (undo is sufficient since data isn't saved yet).

### Keyboard & input improvements

- `inputmode="decimal"` added to all `type="number"` inputs — triggers numeric keypad on mobile instead of full keyboard.
- `openModal()` now auto-focuses the first visible input after 120ms, reducing taps needed on mobile.

### Overwrite protection for saved sessions

- `saveGymSession()` and `saveClimbSession()` now show `confirm()` dialog before overwriting when in edit mode.
- Amber edit-mode banner visible at top of log view when editing a saved session, with a "Cancel" button.
- `cancelGymEdit()` and `cancelClimbEdit()` functions added — discard changes and reset the form cleanly.

### Accessibility basics

- Bottom nav: `role="tablist"`, individual buttons `role="tab"` with `aria-selected` toggled dynamically in `switchTab()`.
- All modals: `role="dialog"` and `aria-modal="true"` on overlay elements.
- All modal close buttons: `aria-label="Close"`.
- `:focus-visible` outlines (2px solid, blue accent) on buttons, inputs, selects, and nav items.
- `prefers-reduced-motion: reduce` media query disables all transitions and animations.
- `lang="en"` already present on `<html>`.

### Empty-state improvements

- Sparse empty states ("No sessions yet") enhanced with actionable guidance ("Log your first session from the Log tab!").
- Empty-state icons enlarged (36px → 44px), text centered with max-width for readability.

---

## Lower-Priority Improvements (April 2026)

### Replace prompt() with in-app modal

- Native `prompt()` calls removed entirely (were used for template naming in Gym and Fingerboard Build).
- Replaced with a shared `showTextModal(title, defaultVal, confirmLabel, cb)` utility — renders a styled bottom-sheet modal with a pre-filled text input, Save and Cancel buttons, and Enter/Escape keyboard support.
- Bonus: template names are now run through `esc()` before appearing in toasts.

### Legacy climbing format migration

- Added `migrateClimbSessionFormat(s)` — upgrades sessions from any of the 4 legacy formats (flat `routes[]`, `blocks[].phases`, `blocks[].entries`, or empty) to the current `warmup/blocks/cooldown` structure in-place.
- Called in `editClimbSession()` with immediate write-back — editing any old session upgrades it permanently.
- Also called lazily in `renderClimbHistory()` — viewing the history tab upgrades all remaining legacy sessions in one pass and persists them.
- Over time, the legacy normalisation paths in `getSessionRoutes()` will become unreachable.

### Inline style extraction

- Added 15 utility CSS classes: `.text-sm-muted`, `.text-xs-muted`, `.text-xxs-muted`, `.text-xxs-muted-nowrap`, `.flex-gap8`, `.flex-gap6`, `.flex-gap4`, `.meta-chip`, `.input-sm`, etc.
- 52 occurrences of repeated inline styles replaced with utility classes across both static HTML and JS template literals.

---

## Web App + GitHub Gist Sync (Apr 2026)

- **Hosting:** GitHub Pages — `https://fpv64ncs5p-maker.github.io/Training-Hub/` (repo: `fpv64ncs5p-maker/Training-Hub`, file: `index.html`)
- **Sync backend:** GitHub Gist API (`api.github.com/gists`) — no server, no account needed beyond GitHub
- **Auth:** GitHub Personal Access Token (classic) with `gist` scope only — entered once in the app, stored in localStorage (`_gh_token`), never in source code
- **Gist file:** `training-hub-data.json` (private Gist, auto-created on first sync)
- **Sync strategy:** Offline-first — localStorage is primary store. On startup: if local has data → push to Gist (local wins); if local is empty → pull from Gist. Every `DB.set()` triggers a debounced push (3s delay).
- **Manual controls (Home → Data section):**
  - ☁️ Push to Cloud — explicitly push all local data to Gist
  - ⬇️ Pull from Cloud — explicitly pull from Gist (use on phone to get computer's data)
- **Sync indicator:** 🟢/🔄/🔴/⚠️ in top-right of Home header
- **Sync Setup card:** Shown on Home tab when no token is stored; hidden once token is saved. Includes "clear token" link to re-enter.
- **Token security:** Never hardcoded — user pastes token into app UI; GitHub secret scanning won't flag it
- **Why not Supabase:** DNS resolution for `pmzzmvzbgeonjnbreze.supabase.co` failed consistently from JavaScript on both Chrome and Safari (ERR_NAME_NOT_RESOLVED), likely due to mobile network DNS filtering or Safari ITP. GitHub API (`api.github.com`) works reliably on all tested networks.
- **Important:** After restoring a backup, always tap ☁️ Push to Cloud to update the Gist with the restored data before using Pull on another device.

---

## Climbing Session Templates — Save/Discard/Resume (Apr 2026)

- **Problem:** Applying a session template populated the session but showed no clear Save/Discard/Resume actions.
- **Fix:** Added a `✕ Clear Session` button next to `Save Session` in the climbing log (mirrors gym module pattern). Button is hidden when session is empty and shown once data exists.
- **Draft/Resume:** The existing draft banner now uses "↩ Resume" label (was "Restore") so it's clearer when returning to an in-progress session after navigating away.
- **`clearClimbSession()`:** New function — resets `climbSession`, clears localStorage draft, calls `renderClimbBlocks()`.

---

## Bug Fixes — Home/Planner Sync & Cloud Race Condition (May 2026)

### Home vs Planner out of sync (ghost sessions)
- **Root cause:** Sessions with a null/undefined `trainingType` could exist in `plan_data` (from old migrations or incomplete adds). The Planner hid them visually (no type = nothing to render), but `renderHomeTodayFocus` and `renderNextUpcomingSession` iterated all sessions without filtering — producing unnamed 🏋️ cards with no label (e.g. "60 min · RPE 7" with no sport) and malformed "Sat ·" next-session previews.
- **Fix 1:** `renderHomeTodayFocus` now filters with `.filter(s=>s&&s.trainingType)` before rendering.
- **Fix 2:** `renderNextUpcomingSession` now finds the first valid session (`validSessions[0]`) per day instead of blindly using `sessions[0]`.
- **Fix 3:** Planner migration filter tightened from `filter(s=>s!==null&&s!==undefined)` to `filter(s=>s!==null&&s!==undefined&&s.trainingType)` — ghost sessions are cleaned out of `plan_data` on next Planner load.

### Cloud sync race condition (multiple tries to push/pull)
- **Root cause:** `_pushToGist()` had no lock, so concurrent callers (`_sbInit` on startup + `_syncKeyToCloud` debounce) could both fire near-simultaneously, causing colliding PATCH requests to the GitHub Gist API. Neither call would fail hard, but the gist could receive partial/overwritten data, or rate-limit errors would cascade.
- **Fix 1:** Added `_pushInProgress` boolean mutex. `_pushToGist()` returns early if a push is already in flight; the `finally` block resets it so subsequent pushes can proceed.
- **Fix 2:** `_syncKeyToCloud()` skips scheduling a new debounced push if `_pushInProgress` is true.
- **Fix 3:** `_sbInit()` startup push is deferred by 500ms so any in-flight debounced sync from a recent save can settle before the startup push fires.

---

## Assessment-Driven Session Building (May 2026)

- **ASSESS_DEFAULTS expanded** — 7 new exercises added to the default gym assessment list, grouped by area:
  - Inferior: Hip Thrust Machine
  - Superior: Low Row, Rear Deltoid N1, Fly Deltoid N2
  - Core: Hanging Knees, Pallof Press, Cable Anti-rotation
  - All exercise names match the EXERCISES library for consistent lookup.

- **`suggestWeightFull()` added** — new companion to `suggestWeight()` that returns `{weight, source, label, stale}`:
  - **Primary source:** latest gym assessment. Uses the Epley formula (`1RM = weight × (1 + reps/30)`) to estimate max from the assessed best set, then applies effort % to get working weight.
  - **Fallback:** existing `suggestWeight()` (phase sessions → all-time sessions → WEIGHT_REF seed).
  - `source` field is `'assessment'` | `'session'` | `'ref'` for UI labelling.
  - `stale: true` when latest assessment is >4 weeks old.

- **`phaseExDefaults(phaseId)` added** — returns phase-specific `{sets, reps, rest}` defaults:
  - Hypertrophy: 3 sets × 10 reps · 1'30" rest
  - Strength: 4 sets × 5 reps · 3' rest
  - Power: 4 sets × 3 reps · 4' rest
  - Deload: 2 sets × 10 reps · 1'30" rest

- **`generatePlan()` updated:**
  - Phase defaults applied to every non-warmup exercise when a macro phase is active (overrides exercise library defaults for sets/reps/rest).
  - `exTimeSec` now receives the phase-overridden exercise object so time estimates are accurate.
  - Build result shows assessment banner with date + stale warning (>4 wks) if applicable.
  - Each exercise row shows a 📋 badge when weight is derived from assessment (with tooltip showing est. 1RM).

---

## Template Session Bug Fixes — Edit Modal Smartening (May 2026)

Reported after a gym test: template-loaded exercises wouldn't accept new weight input, brand-new exercises added on top of a template didn't pull from the latest assessment, and the weight ↔ effort % fields didn't recalculate from each other.

**Root cause:** The in-session ✏️ edit modal (`modal-edit-history-ex`) was a "dumb" form — it just read/wrote stored values with no assessment lookup and no link between weight and intensity. The ADD modal had partial linkage (effort → weight only). On EU iOS keyboards, `type="number"` weight fields also silently blanked when a comma decimal was typed.

**Fixes:**

- **Inputs switched to `type="text" inputmode="decimal"`** on `#ex-weight` and `#edit-hist-weight` to accept comma decimals without blanking. New helper `_normalizeKgInput()` converts comma → dot on input and on save.
- **`_fillEditHistModal()` now calls `suggestWeightFull()`** on open. Caches est. 1RM in `_editEx1RM`. If the exercise's weight is empty (typical for template-loaded exercises), it auto-fills from the assessment-based suggestion and shows a 📋 source label (with ⚠️ if the assessment is >4 weeks stale).
- **Bidirectional weight ↔ effort recalc** in the edit modal:
  - `recalcEditWeight()` — fires on intensity `oninput`, recomputes weight from cached 1RM.
  - `recalcEditIntensity()` — fires on weight `oninput`, recomputes effort % from cached 1RM (clamped 30–130% as sanity bounds).
  - `_editRecalcLock` flag guards against any future recursion.
- **ADD modal: weight → effort link** via new `onExWeightChange()` on `#ex-weight`. The existing `calcSuggestedWeight()` on intensity remains (effort → weight). Both directions now stay in sync.
- **Save paths normalized:** both branches of `saveEditHistoryExercise()` and `addExerciseToSession()` run weight through `_normalizeKgInput()` before persisting.

---

## Live Session — Per-Set Completion Tracking (May 2026)

Reported: during a gym session, the in-session exercise list was static — no way to mark exercises as done without deleting them. Jo wanted glanceable progress tracking mid-workout.

**Design (Jo's combined picks):**

- **Per-set circle dots** under each strength exercise card. Tap a dot to mark that set done; tap the last filled dot to unfill. Filled = green ✓. Label reads "2 of 3 sets" / "all done ✓".
- **Cardio exercises** get a single done/not-done dot (no sets).
- **Tap-exercise-name shortcut** — toggles all sets done / all undone in one tap (escape hatch for users who don't want per-set granularity).
- **Auto-sort to bottom** — when all sets are done, the card auto-fades (opacity .55, strike-through name) and sinks into a collapsible **✓ Completed (N)** section below the remaining ones. Tap the header divider to collapse/expand.
- **Persistence** — `e.doneSets` (strength) and `e.done` (cardio) are stored on each exercise inside `gymSession`. They survive page reload via `_saveGymDraft()` and are saved with the session on submit, opening the door to future adherence analytics (planned vs actual sets).

**Files touched (index.html):**
- New CSS classes: `.set-dots`, `.set-dot[.done]`, `.set-dots-label`, `.ex-row.done`, `.done-section-header`, `.done-section-collapsed`.
- `renderSessionExercises()` rewritten to split active/done lists, render per-row dots, and emit the Completed section divider.
- New helpers: `_isExerciseDone()`, `_renderExRow()`, `toggleExerciseSet()`, `toggleExerciseDone()`, `toggleDoneSection()`.

**Bonus typo guard:** the in-session edit modal's reps input now uses `inputmode="numeric"` with a digit/time-pattern regex (`[0-9'"\s×x]*`) — addresses the `3×109` typo seen in a gym screenshot (Hip Adductor template entry).

---

## Documentation

- **Specs document created as .docx** — `Training Hub Spec v1.0.docx` (initial), then updated to `Training Hub Spec v2.0.docx` after the Fingerboard module and other features were added.
- **Generated via python-docx** — npm registry was blocked (403), so python-docx via pip was used instead of the docx skill's Node.js path.
- **Decisions and Preferences tracked separately** — this file (`decisions.md`) and `preferences.md` created to maintain a running record.
