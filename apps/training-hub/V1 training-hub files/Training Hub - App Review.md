# Training Hub — Comprehensive App Review

**Date:** 12 April 2026
**Reviewed by:** Claude (for Jo Bernardes)
**File:** `training-hub.html` (~6,400 lines, single-file HTML/CSS/JS)

---

## Executive Summary

Training Hub is a surprisingly capable personal training tracker built as a single offline HTML file. It covers gym, climbing, fingerboard, rehab, stretching, planning, and assessments — essentially replacing a multi-sheet Excel workbook. The app does a lot of things well, especially for a personal tool, but at 6,400 lines in a single file, it's approaching a complexity ceiling that will make future changes increasingly fragile. Below is a thorough review from both the user experience and technical/development perspectives.

---

## Part 1: User Experience Review

### What works well

**Information architecture is thoughtful.** The five bottom-nav tabs (Home, Gym, Climbing, Rehab, Planner) map cleanly to the user's mental model of their training week. Sub-tabs within Gym and Climbing break complex modules into focused views (Log, Build, History, Progress, Macro, Assess, Stretch). This is solid for a mobile-first app.

**The Home screen is well-designed.** Today's Focus, the weekly calendar with emoji icons, and the MoM momentum cards give a quick "state of my training" at a glance. The delta arrows (up/down/stable) are motivating without being overwhelming.

**Climbing session logging is sophisticated.** The block-based system (Routes, Board, ARC) with warm-up/main/cool-down phases, batch entry, and multi-wall support is very well thought out. The climbing templates (grade-filtered, one-tap apply) make repetitive sessions fast.

**The Grade Pyramid is a standout feature.** It provides clear visual progress toward climbing goals with OS/RP stacked bars. Showing "working on" projects as red dots is a nice motivational touch.

**Data entry is fast.** Auto-fill from templates, suggested weights, auto-colon for time inputs, category chip filters, and batch route entry (grade + result + count in one action) all reduce friction.

### Areas for improvement

**Tab overflow is becoming a problem.** The Gym segment bar has 7 buttons (Macro, Log, Build, History, Progress, Assess, Stretch) and the Climbing tab has 6. On small screens these require horizontal scrolling. Users may not discover tabs that are off-screen. Consider grouping less-used features (e.g., Macro + Assess could live under a "Tools" umbrella, or use a dropdown/overflow menu).

**No confirmation before navigating away from unsaved work.** If you're mid-way through building a gym session (multiple exercises added) and accidentally tap a different nav tab, everything is lost. There's no dirty-state warning. This is the single most frustrating UX gap for a logging app.

**Session duration isn't auto-calculated from start/end times in all contexts.** The gym log does this, but it's inconsistent — climbing sessions have a manual "Duration (min)" field even though they could also use start/end times.

**No undo/redo.** Deleting an exercise, a route entry, or a stretch session is immediate and irreversible (only a `confirm()` dialog guards full deletions). For a data-heavy app where typos happen, a simple undo stack (even just "undo last delete") would prevent frustration.

**History scrolling gets unwieldy.** Gym and climbing history render all sessions as a flat list. After a few months of consistent training, this will become a very long scroll. Date-based filtering, search, or pagination would help.

**Monthly Resume heatmap lacks a legend.** The intensity-colour system (blood orange / mustard / mint) is documented in the decisions log, but there's no on-screen legend. A first-time user of the app won't know what the colours mean.

**No data export.** All data lives in localStorage with no way to back it up or move to a new device. A single "Export JSON" / "Import JSON" button would be a critical safety net. This is the biggest risk to the app's long-term usefulness — one browser cache clear and everything is gone.

**Planner's monthly view toggle is easy to miss.** The Weekly/Monthly buttons at the top of the Planner tab look like regular ghost buttons, not a view toggle. A segment control (like the ones used in Gym/Climbing sub-tabs) would make the toggle more discoverable.

**Empty states could guide better.** Some empty states (e.g., "No assessments yet") tell the user what's missing but don't explain *why* they'd want to add one. A sentence like "Record your best set per exercise at the end of each training phase to track strength gains" turns an empty state into a coaching moment.

---

## Part 2: Technical & Development Review

### Architecture

**Single-file approach: strength and weakness.** The decision to keep everything in one HTML file with zero dependencies is great for offline use and simplicity. But at 6,400 lines, the file is getting hard to navigate. Finding where a specific function is defined requires searching, and CSS class name collisions have already caused bugs (the `.week-day` conflict between Home and Planner is documented in the decisions log).

**localStorage as the only persistence layer is risky.** There's no data integrity protection — `JSON.parse` failures are caught with `try/catch` returning `null`, but there's no schema validation, no migration versioning, and no backup. If a single `localStorage.setItem` call writes corrupted JSON (e.g., due to a quota exceeded error), the entire dataset for that key is lost silently.

**No error boundaries.** If `renderClimbBlocks()` throws (e.g., accessing a property on undefined because of a data format edge case), the whole tab stops rendering. There's no try/catch around render functions, no fallback UI.

### Code quality

**The DB object is clean and consistent.** The pattern of `get(key) → array`, `save(item) → unshift`, `update(item) → map`, `delete(id) → filter` is well-structured and easy to follow. Good use of a data access layer even in a small app.

**The `getSessionRoutes()` normaliser is well-engineered.** Supporting 4 legacy data formats (A through D) through a single normalisation function is the right approach. The `normResult()` helper for case normalisation shows attention to data integrity.

**Inline styles are heavily used.** Many elements are styled with `style="..."` attributes directly in the HTML template strings rather than using CSS classes. This makes the app harder to theme, harder to maintain, and creates very long, hard-to-read template literal strings. Examples: the Build Session card, the climbing block renderer, and the assessment modal all have extensive inline styles.

**HTML is generated via string concatenation (template literals).** This is workable for a small app, but it creates XSS risks if any user-entered data (exercise names, notes) contains HTML characters. There's no `escapeHtml()` utility. If a note contains `<script>` or even just an unescaped `<`, the rendered HTML will break.

**Global state is scattered.** Variables like `gymSession`, `gymEditId`, `climbSession`, `climbBlocks`, `currentWeekStart`, `_expandedDays`, `selectedStretchMuscles`, `assessExercises`, `_editRouteCtx` are all declared at various points in the file. There's no single state management pattern. This makes it hard to reason about what state the app is in at any moment.

**Event handlers are inline `onclick` attributes.** Every button uses `onclick="functionName()"` rather than `addEventListener`. This works fine but tightly couples HTML and JS, and makes it harder to add event delegation or prevent double-taps.

**`prompt()` is used for user input.** The template naming flow uses `const name = prompt('Template name:', defaultName)`. This is a jarring UX break on mobile — native prompts look out of place in a well-designed app and can't be styled.

**Magic numbers appear in several places.** Rest period parsing (`restToSec`), exercise duration estimation (`exTimeSec`), and the phase-session blending threshold (`phaseSessions.length < 3`) all use hardcoded numbers without constants or comments explaining why those specific values were chosen.

### Data model observations

**Climbing session format evolution is well-handled but complex.** Four formats (A-D) co-exist, and the normaliser handles them. However, there's no migration-on-read that upgrades old formats to the current one. This means every read of historical data pays the normalisation cost, and the normalisation logic must be maintained forever.

**No data versioning.** There's no `version` field in localStorage to track schema changes. If the planner data structure changes again (it already migrated from flat to `sessions[]`), there's no clean way to know whether a record has been migrated.

**IDs are `Date.now()` timestamps.** This works for a single-user app but creates collision risks if two items are saved in the same millisecond (e.g., batch operations). Using `Date.now() + Math.random().toString(36).slice(2)` would be safer.

### Performance considerations

**Rendering is eager and full.** Functions like `renderGymHistory()` and `renderClimbHistory()` rebuild the entire DOM for their section on every call. With a growing dataset, this will become noticeably slow. The Monthly Resume with heatmaps and trend charts for 12 months of data is the most expensive render path.

**No virtualisation or pagination.** History lists render all items. After a year of training (100+ gym sessions, 100+ climb sessions), these lists will contain thousands of DOM nodes.

**`suggestWeight()` iterates all sessions on every exercise selection.** For a library of 50+ exercises and 100+ sessions, this is fine. But it's O(sessions × exercises_per_session) with no caching — it could be memoised.

### Maintainability

**The file is well-documented externally** (PROJECT_CONTEXT.md, decisions.md, preferences.md, ACSM_improvements.md are all excellent), but the code itself has minimal comments. Functions are generally well-named, but complex logic sections (e.g., the phase-aware suggest/generate flow, the pyramid aggregation) would benefit from inline documentation.

**CSS class naming has no convention.** Some classes use BEM-like patterns (`.ex-row-info`, `.day-done`), others are generic (`.card`, `.tags`), and some are feature-specific (`.py-tier`, `.month-delta`). A consistent naming strategy would reduce collision risk.

**No test coverage.** For critical calculation logic (route counting, meter calculations, volume aggregation, weight suggestions, MoM deltas), unit tests would catch regressions. The bug history in the spec shows several calculation errors that were caught through manual testing — automated tests would have caught them earlier.

---

## Part 3: Priority Recommendations

### Critical (do these first)

1. **Add JSON export/import** — One button to download all localStorage as a JSON file, one to restore from a file. This is insurance against data loss and enables device migration.
2. **Add unsaved-work protection** — Track dirty state for gym/climbing sessions and warn before navigation.
3. **Add `escapeHtml()` utility** — Sanitise all user-entered text before injecting into template literals.

### High value

4. **History pagination or date filtering** — Show last 20 sessions by default with a "Load more" button.
5. **Replace `prompt()` with in-app modals** — Already have a modal pattern; extend it for text input.
6. **Add localStorage quota monitoring** — Show a warning if approaching the 5-10MB limit; suggest export.

### Medium term

7. **Extract CSS to a consistent class system** — Move inline styles to named classes.
8. **Consider splitting into modules** — Even without a build step, the JS could be split into separate `<script>` blocks or use ES module patterns for better organisation.
9. **Add lightweight undo** — Store the last deleted item in memory; show a "tap to undo" toast.
10. **Migrate legacy climbing formats on save** — When a session is viewed in detail, upgrade its format in-place so normalisation cost decreases over time.

---

## Overall Assessment

This is an impressive personal app. The domain modelling (climbing grades, periodisation phases, Lattice assessments, ACSM-informed features) shows deep understanding of the training domain. The UX is mobile-first and intentional. The main risks are around data durability (no backup) and maintainability (single-file complexity). The recommended next step — data export — would immediately make the app safer to rely on daily.
