# Training Hub — Project Context

**Last updated:** 2026-04-30

---

## Quick Facts

- **App:** Training Hub (single-file HTML, offline, localStorage)
- **User:** Jo Bernardes (josina.md.bernardes@gmail.com)
- **Tech:** Pure HTML/CSS/JS, ~5873 lines
- **Max width:** 700px (mobile-first)
- **Tabs:** Home · Gym · Climbing · Rehab · Planner · Fingerboard

---

## Jo's Training Context

- **Sport climbing:** OS 6c+ → RP target 7a (Lattice assessed Jan 2026)
- **Boulder:** OS V4 → RP target V5
- **Gym split:** Inferior+core · Superior+wrist · Fingerboard (separate)
- **Gyms:** Neoliet (13m/20m), Sterk (4m), Klimmuur (16m)
- **Rehab:** Calf protocol (post-surgery Aug 2025)
- **Fingerboard:** Trained on both climbing and rest days
- **Macrocycle peak:** October 2025

---

## Jo's Preferences

- **Keep it brief** — short explanations, no lengthy preambles
- **Ask before deciding** — options before building
- **Light, compact, mobile-friendly** — no dark heavy themes
- **Simple first** — add features when they make sense
- **Offline only** — no external dependencies
- **Specs stay current** — update docs when features change

---

## App Architecture

| Section | Lines (approx) | Content |
|---------|----------------|---------|
| CSS | 1–290 | All styling (light mode, activity colours, home screen) |
| HTML | 291–780 | Tab panels (Home · Gym · Climb · Rehab · Plan · FB) + modals |
| Constants | 780–1050 | Training types, grades, gym heights, etc. |
| DB + Utils | 1050–1250 | Data layer (localStorage) + helpers |
| Gym logic | 1250–2000 | Session log, build, history, progress |
| Climbing | 2000–3000 | Session log, pyramid, history, detail editor |
| Planner | 4400–5100 | Weekly planner + monthly resume |
| Fingerboard | 5100–5500 | Separate tab (own storage, templates) |
| Home screen | 5500–5870 | renderHome, trends, week calendar, motivation |

### Key Data Objects

```js
// Gym
DB.gymSessions()  // array of {date, gym, exercises:[]}
DB.saveGym(s)

// Climbing — current format
DB.climbSessions()  // {date, gym, warmup:[], blocks:[{climbingType, wallHeight, routes:[]}], cooldown:[]}

// Fingerboard
DB.fbSessions()  // separate storage

// Planner
DB.planData()  // by week key {YYYY-MM-DD: [{day, date, work, workStart, workEnd, done, sessions:[{trainingType,...}]}]}
```

### Climbing Session Format History
Legacy formats are still supported via `getSessionRoutes(s)` normaliser:
- **Format A** — `routes[]` flat array
- **Format B** — `entries[]`
- **Format C** — `phases:{warmup, main, cooldown}`
- **Format D (current)** — `warmup:[], blocks:[{climbingType, wallHeight, routes:[]}], cooldown:[]`

---

## Decisions Log

1. **Fingerboard is separate** — own tab, own storage, no overlap with Gym Fingers
2. **Assessments are manual** — Jo enters Lattice data herself
3. **Templates discoverable** — placed at top of Build Session
4. **History is editable** — can fix/add exercises without rebuilding
5. **Dark theme → Light theme** — switched from dark-on-dark to light mode
6. **Compact spacing** — mobile-first, tighter layout
7. **Down-climbing counts** — routes + meters + movements, but NOT as a send for Projects
8. **Home screen is default tab** — replaces old Gym log landing page; uses purple accent
9. **Active days = Gym + Climbing + Tennis + Golf only** — Rehab, Fingerboard, and rest days excluded
10. **Planner row layout** — day name left, activities tight-left, buttons margin-left:auto right; `flex:0 1 auto` on middle section
11. **Climbing multi-wall** — each block has its own wall height + climbing type (Lead/Top Rope/Boulder)

---

## Design System

### Activity Colours
- Gym: `#2ea043` (green)
- Climbing: `#388bfd` (blue)
- Fingerboard: `#7c3aed` (purple)
- Tennis: `#a78bfa` (lavender)
- Golf: `#34d399` (mint)
- Active: `#8b949e` (grey)
- Rehab: `#f0883e` (orange)
- Rest: `#484f58` (dark grey)

### Climbing Grades & Pyramid
Target structure for 2026:
- 7b–7b+ (Project)
- 7a–7a+ (RP Target) → OS target: 1, RP target: 2
- 6c–6c+ (Build) → OS target: 2, RP target: 4
- 6b–6b+ (Solid) → OS target: 4, RP target: 8
- 6a–6a+ (Warm-up) → OS target: 8, RP target: 16
- 5c–5c+ (Volume) → OS target: 16, RP target: 20

---

## Home Screen Implementation (Apr 8, 2026)

**Status:** ✅ Complete

### Components
1. **Today's Focus** — Shows all planned sessions for today; shows next upcoming session if none today
2. **This Week Calendar** — 7-day grid with activity icons (💪 🧗 🎾 ⛳ 😴); counts active days (Gym, Climb, Tennis, Golf only)
3. **Climbing Momentum** — Month-over-month trends: routes, sends, meters, top grade with ▲▼→ indicators
4. **Gym Momentum** — Month-over-month trends: sessions, total volume (tonnes), hours with ▲▼→ indicators

### Data Flow
- **Today's sessions:** Pulled from Planner data for current date
- **Week calendar:** Pulls from Planner, counts only Gym/Climbing/Tennis/Golf activities
- **Motivation metrics:** Calculated from Climbing and Gym session histories, compared to previous month
- **Auto-refresh:** Home screen re-renders when tab is selected (fresh calculations)

### Key Functions
- `renderHome()` — Main orchestrator
- `renderHomeTodayFocus()` — Today's sessions + next upcoming
- `renderHomeWeekCalendar()` — 7-day calendar with icons and active day count
- `renderHomeMotivation()` — MoM trends for climbing and gym
- `getClimbingTrends()` — Calculates climbing metrics MoM
- `getGymTrends()` — Calculates gym metrics MoM (volume in tonnes, time in hours)
- `getDelta()` — Formats percentage change with arrows (▲ up, ▼ down, → stable)

### Design Decisions
- **Active days:** Count only Gym + Climbing + Tennis + Golf (not Rehab, Fingerboard, or rest)
- **MoM comparison:** Compare current month vs previous calendar month (not rolling 30 days)
- **Gym volume:** Calculated as sum of (sets × reps × weight) per session, converted to tonnes
- **Empty states:** Shows "No sessions planned" if Planner empty; shows metric as 0 if no data
- **Nav button:** Home is now default active tab, uses purple accent (#7c3aed) to match Planner

---

## Session Apr 9, 2026 — Fixes Applied

### Planner layout left-alignment (✅ Fixed)
- **Root cause:** Home screen calendar class `.week-day` was conflicting with planner's `.week-day`, adding `align-items:center; text-align:center` to planner rows
- **Fix 1:** Renamed home screen CSS class → `.home-cal-day`, `.home-cal-day-label`, `.home-cal-day-date`
- **Fix 2:** Updated `renderHomeWeekCalendar()` JS to use `.home-cal-day` class names
- **Fix 3:** Changed middle section of day rows from `flex:1` → `flex:0 1 auto` so activities snap left after day name instead of floating in the middle

### Climbing session — multi-wall support (✅ Fixed, Apr 8)
- Restructured climbing session to `{ warmup:[], blocks:[], cooldown:[] }`
- Each block has its own `wallHeight` and `climbingType` (Lead/Top Rope/Boulder)
- Layout: Warm-up card → Block N cards → Cool-down card
- Fixed: `addRouteToSection()` prefix bug (`wa` vs `wu`)
- Fixed: pencil edit button in sections and blocks now works

### Planner expand/collapse (✅ Fixed, Apr 8)
- Added `let _expandedDays = new Set()` to track state across re-renders
- `toggleDay(i)` toggles set; `renderPlanner()` applies `.open` class during render
- Week navigation clears expanded state

---

## Deployment Workflow (GitHub Pages)

- **Repo:** `fpv64ncs5p-maker/Training-Hub` → `index.html` on `main` branch
- **Live URL:** `https://fpv64ncs5p-maker.github.io/Training-Hub/`
- **Deploy from Mac Terminal** (needs a token with `repo` scope):
```bash
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
- **Tokens needed:** `repo` scope for deploy · `gist` scope for data sync (stored in app localStorage)
- **After deploy on phone:** delete PWA icon → open URL in Safari → Add to Home Screen → Pull from Cloud
- **GitHub account:** `@fpv64ncs5p-maker` (Apple private relay email, verify via that inbox)

---

## Next Steps / Ideas

- [ ] Add weekly streak indicator (consecutive days with activity)
- [ ] Show "this week vs last week" comparison (not just MoM)
- [ ] Personal record callout ("Personal best: 7a Flash this month!")
- [ ] Quick-action buttons to log today's session directly from home
- [ ] Customize home screen sections (hide/show climbing/gym/other)
- [ ] Add "Days until peak" if macrocycle is set
