# CLAUDE.md — Training Hub

> Project memory for Claude. Captures what we've built, every decision made, Jo's preferences, and useful context to avoid re-litigating the same questions.  
> **Last updated:** 2026-05-22

---

## Project at a Glance

| | |
|---|---|
| **App name** | Training Hub |
| **File** | `index.html` (single-file, ~7 000+ lines HTML/CSS/JS) |
| **Live URL** | `https://fpv64ncs5p-maker.github.io/Training-Hub/` |
| **GitHub repo** | `fpv64ncs5p-maker/Training-Hub` — `index.html` on `main` |
| **GitHub account** | `@fpv64ncs5p-maker` (Apple private-relay email) |
| **Storage** | `localStorage` only — offline-first, no backend |
| **Sync** | GitHub Gist API (`gist` scope token, stored in `_gh_token`) |
| **Max width** | 700 px (mobile-first) |
| **Tabs** | Home · Gym · Climbing · Rehab · Planner |

---

## Jo's Training Profile

- **Sport climbing:** OS 6c+ → RP target 7a (Lattice Jan 2026)
- **Bouldering:** OS V4 → RP target V5
- **Gyms:** Neoliet (13 m indoor / 20 m outdoor) · Sterk (bouldering, 4 m) · Klimmuur (16 m)
- **Gym split:** Inferior + Core · Superior + Wrist · Fingerboard (separate)
- **Rehab:** Calf post-surgery (Aug 2025), FisioHolland protocol
- **Fingerboard:** Done on both climbing and off-climbing days
- **Macrocycle peak target:** October 2025 (climbing)

---

## Working with Jo — Preferences

- **Keep it brief.** Short explanations, no preambles. Get to the point.
- **Ask before building.** For any non-trivial design or feature decision, offer options (A / B / C) and wait for a choice.
- **Suggest proactively.** Flag ideas and potential problems, but frame them as suggestions — don't act unilaterally.
- **Clarify when unsure.** One focused question beats building the wrong thing.
- **Encourage creativity.** Jo is open to thinking about things differently.
- **Specs stay current.** Update `decisions.md` (and if significant, the `.docx` spec) when features change.
- **Maintain a context file.** This file (`CLAUDE.md`) should be updated whenever there are meaningful new decisions, fixes, or preference changes.

---

## Tech Stack & Architecture

```
index.html
├── CSS            (~1–290)     Light-mode design system, activity colours, home screen
├── HTML           (~291–780)   Tab panels (Home · Gym · Climb · Rehab · Plan) + modals
├── Constants      (~780–1050)  Training types, grades, gym heights, exercise library
├── DB + Utils     (~1050–1250) localStorage data layer + helpers (esc, toast, undo)
├── Gym logic      (~1250–2000) Session log, build, history, templates, progress
├── Climbing       (~2000–3000) Session log, pyramid, history, detail editor
├── Planner        (~4400–5100) Weekly planner + monthly résumé
├── Fingerboard    (~5100–5500) Climbing Gym tab (own storage + templates)
└── Home screen    (~5500+)     renderHome, trends, week calendar, motivation
```

### Key Data Objects

```js
DB.gymSessions()       // [{date, gym, goal, exercises:[]}]
DB.climbSessions()     // [{date, gym, warmup:[], blocks:[{climbingType, wallHeight, routes:[]}], cooldown:[]}]
DB.fbSessions()        // Climbing Gym / Fingerboard sessions (separate storage)
DB.planData()          // {YYYY-MM-DD: [{day, date, work, workStart, workEnd, done, sessions:[...]}]}
DB.macroData()         // Climbing macrocycle config
DB.gymMacroData()      // Gym macrocycle config
DB.gymAssessments()    // Gym assessment log
DB.selfAssessments()   // Climbing self-assessment log
DB.stretchSessions()   // Stretch/mobility log
DATA_KEYS              // Array of all 14 localStorage keys (used for export/import)
```

### Climbing Session Format History
All old formats still normalise through `getSessionRoutes(s)` and `migrateClimbSessionFormat(s)`:
- **Format A** — `routes[]` flat array
- **Format B** — `entries[]`
- **Format C** — `phases:{warmup, main, cooldown}`
- **Format D (current)** — `warmup:[], blocks:[{climbingType, wallHeight, routes:[]}], cooldown:[]`

---

## Design System

### Activity Colours
| Module | Colour |
|---|---|
| Gym | `#15803d` green |
| Climbing | `#1d4ed8` blue |
| Fingerboard / Climbing Gym | `#7c3aed` purple |
| Tennis | `#a78bfa` lavender |
| Golf | `#34d399` mint |
| Rehab | `#ea580c` orange |
| Planner | `#6d28d9` purple |

### Visual Design Principles
- Light mode only (CSS custom properties on `:root` — dark toggle possible later)
- Compact spacing — mobile-first, tighter padding, smaller label font sizes
- Bold & sporty (Apr 2026 refresh): 22 px / weight-800 headers, 28 px stat values, 4 px left-border card accents, pill toast, stronger shadows

### Climbing Grade Pyramid Targets (2026)
| Band | OS target | RP target |
|---|---|---|
| 7b–7b+ (Project) | — | — |
| 7a–7a+ (RP) | 1 | 2 |
| 6c–6c+ (Build) | 2 | 4 |
| 6b–6b+ (Solid) | 4 | 8 |
| 6a–6a+ (Warm-up) | 8 | 16 |
| 5c–5c+ (Volume) | 16 | 20 |

---

## Key Decisions

### Architecture
1. **Single-file HTML** — everything in one `index.html`. No external CDN, no build step, full offline.
2. **localStorage only** — no backend, no login. `DATA_KEYS` constant covers all 14 keys for export/import.
3. **Gist sync** — GitHub Gist API is the cross-device sync layer (not Supabase — DNS failed on Safari/mobile).

### Navigation & Structure
4. **Home is default tab** — replaces old Gym log landing. Uses purple accent `#7c3aed`.
5. **Fingerboard moved to Climbing tab** — renamed "Climbing Gym", 5th seg-btn in Climbing. Storage/logic unchanged.
6. **Gym Macro is first seg-btn** — gives phase context before logging. Log remains the default active panel on open.

### Gym Module
7. **Session Goal field** — Strength / Hypertrophy / Power / Endurance / General. Shows ACSM FITT-VP hint inline.
8. **Templates discoverable** — placed at the top of Build Session, not buried.
9. **Per-exercise editing in History** — ✏️ / 🗑 per exercise; edit modal supports strength, cardio, time-based types.
10. **Gym Assessments use Jo's actual exercises** — not ACSM standard benchmarks. Dynamic exercise list from EXERCISES library. Best-set format: `weight × reps` / `sec` / `max reps` / `cm` depending on type.
11. **Phase-aware `suggestWeight()`** — 3-tier lookup: current macro phase sessions → all-time sessions → `WEIGHT_REF` seed.
12. **`suggestWeightFull()`** — uses Epley formula from latest gym assessment as primary source; falls back to sessions.
13. **`generatePlan()` frequency-sorts** — most-used exercises within the current macro phase fill the plan first.
14. **Per-set completion dots** (May 2026) — green circle dots per strength set, tap to mark done. Auto-sort completed exercises to a collapsible "✓ Completed" section. `doneSets` / `done` persisted in draft.

### Climbing Module
15. **Block-based session** — each session: `warmup`, `blocks[]` (each with own `wallHeight` + `climbingType`), `cooldown`.
16. **Down-climbing counts** — doubles meter count, counts as a send. Does NOT count for Projects.
17. **Sends definition** — OS + Flash + RP + Repeat + climbed-down = sends. Project = not a send.
18. **Pyramid shows Projects** — as 🔴 "working on" markers. Only OS/Flash/RP count toward targets.
19. **Lattice Assessment inside Pyramid sub-tab** — stacked sections: Assessment on top, Pyramid below.
20. **Self-Assessment wizard** — 8 categories × 5 questions scored 1–5, with band feedback. History with delta arrows.
21. **Climbing templates** — 10 pre-built templates (Base/Power × 5 grades). Grade filter defaults to 6c+. One-tap apply pre-fills all phases.

### Climbing Gym (formerly Fingerboard)
22. **Renamed** — "Fingers / Fingerboard" → "Climbing Gym". Fully independent storage (`fb_sessions`, `fb_templates`).
23. **New exercise library** — 6 CG- categories: `CG-Fingers`, `CG-Arms`, `CG-Antagonist`, `CG-Rotator`, `CG-Push`, `CG-Core`. Sourced from `Training charts.xlsx`.
24. **Level field** — `level:"both"` (Beginner + Intermediate) or `level:"intermediate"`. Build tab has All / 🟢 / 🔶 filter.

### Planner Module
25. **Multi-session per day** — `sessions[]` array. Work days + off days: up to 3 slots (Morning / Afternoon / Evening).
26. **Work day header is a visual timeline** — reads left-to-right: morning activity → 💼 work badge → after-work activity.
27. **Active days = Gym + Climbing + Tennis + Golf only** — Rehab, Fingerboard, and rest excluded from week count.
28. **Week Totals widget** — cross-references actual logged sessions (not planner free-text). Shows Gym / Climbing / FB metrics. Hidden when empty.
29. **Data migration on load** — old flat `trainingType` entries auto-migrate to `sessions[]`. Ghost sessions (null `trainingType`) cleaned on Planner load.

### Data Safety
30. **JSON export/import** — `exportAllData()` / `importAllData()` on Home screen. Timestamped file, version check, confirmation on import.
31. **Unsaved-work protection** — `markDirty()` / `clearDirty()` / `isDirty()`. `switchTab()` warns before navigating away. `beforeunload` handler too.
32. **Undo for deletes** — `pushUndo()` / `showUndoToast()` (5 s window). In-session deletes: no confirm, undo only. DB-persisted deletes: confirm + undo.
33. **HTML escaping** — `esc()` utility applied to all user-entered text in template literals (prevents XSS from notes).
34. **Storage monitoring** — Home screen shows localStorage usage (KB + % of 5 MB) with red warning >80%.
35. **Gist push mutex** — `_pushInProgress` boolean prevents concurrent PATCH requests. Startup push deferred 500 ms.

### UX Details
36. **Overwrite protection** — `saveGymSession()` and `saveClimbSession()` confirm before overwriting in edit mode. Amber edit-mode banner with Cancel button.
37. **History pagination** — 20 sessions per page, "Load more" button. Counters reset on entering history mode.
38. **Inputs: `type="text" inputmode="decimal"`** on weight fields (accepts comma decimals on EU iOS). `_normalizeKgInput()` converts comma → dot on save.
39. **`openModal()` auto-focuses** first visible input after 120 ms.
40. **Accessibility basics** — `role="tablist/tab"`, `role="dialog"`, `aria-modal`, `aria-label="Close"`, `:focus-visible` outlines, `prefers-reduced-motion`.
41. **Utility CSS classes** — 15 classes (`.text-sm-muted`, `.flex-gap8`, `.meta-chip`, etc.) replacing inline styles.

---

## Deployment

```bash
# Deploy index.html to GitHub Pages (needs TOKEN with `repo` scope)
SHA=$(curl -s -H "Authorization: Bearer TOKEN" \
  "https://api.github.com/repos/fpv64ncs5p-maker/Training-Hub/contents/index.html" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])") && \
curl -s -X PUT \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/fpv64ncs5p-maker/Training-Hub/contents/index.html" \
  -d "{\"message\":\"Deploy update\",\"sha\":\"$SHA\",\"content\":\"$(base64 -i ~/Library/Mobile\ Documents/com~apple~CloudDocs/01\ Claude\ in\ Docs/02\ Projects/PROJ0004_training\ app/index.html)\"}" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('✅ Done!' if 'content' in d else d.get('message','Error'))"
```

**After deploying to phone:** delete PWA icon → open URL in Safari → Add to Home Screen → Pull from Cloud.  
**Tokens needed:** `repo` scope (deploy) · `gist` scope (data sync).

---

## Bug Fixes Log

| Date | Issue | Fix |
|---|---|---|
| Apr 9, 2026 | Home `.week-day` CSS conflicted with Planner `.week-day`, misaligning rows | Renamed home calendar classes to `.home-cal-day` |
| Apr 9, 2026 | Climbing `addRouteToSection()` prefix bug (`wa` vs `wu`) | Fixed prefix |
| Apr 9, 2026 | Planner expand/collapse lost state on re-render | Added `_expandedDays = new Set()`, persisted across renders |
| Mar 2026 | Week Totals read unmigrated planner data (Golf/Tennis invisible) | Moved `renderWeekTotals()` call to after migration |
| May 2026 | Home showing ghost sessions (null `trainingType`) in Today's Focus | Added `.filter(s=>s&&s.trainingType)` in home render functions |
| May 2026 | Cloud sync race condition — concurrent PATCH requests to Gist | Added `_pushInProgress` mutex + 500 ms startup delay |
| May 2026 | Template-loaded exercises: weight field blank on iOS comma decimal | Switched to `type="text" inputmode="decimal"` + `_normalizeKgInput()` |
| May 2026 | Edit modal: no assessment lookup, no weight↔effort recalc | `_fillEditHistModal()` calls `suggestWeightFull()`, bidirectional recalc added |

---

## Documents in This Folder

| File | Purpose |
|---|---|
| `index.html` | The app (current, live version) |
| `training-hub 2.html` | Older snapshot |
| `decisions.md` | Detailed decisions log (full narrative version) |
| `preferences.md` | Jo's working and design preferences |
| `PROJECT_CONTEXT.md` | Broader context (slightly older) |
| `Training Hub - App Review.md` | UX + technical review (Apr 12, 2026) |
| `Training Hub Spec v2.0.docx` | Latest feature spec |
| `ACSM_improvements.md` | ACSM-based feature notes |
| `training-hub-backup-*.json` | Data backups |
| `Jo_training raw docs 25_2026/` | Source Excel training data |
| `Lattice&climb assessments/` | Lattice PDFs + climb assessment sheets |

---

## Open Ideas / Next Steps

- [ ] Weekly streak indicator (consecutive active days)
- [ ] "This week vs last week" comparison on Home (not just MoM)
- [ ] Personal record callout ("7a Flash this month!")
- [ ] Quick-action buttons to log today's session directly from Home
- [ ] Customisable Home sections (hide/show)
- [ ] "Days until peak" if macrocycle is set
- [ ] Monthly heatmap legend (intensity colour key)
- [ ] Planner monthly/weekly toggle as a proper segment control
- [ ] Tab overflow solution for Gym (7 sub-tabs) and Climbing (6 sub-tabs)
