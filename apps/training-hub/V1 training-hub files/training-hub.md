# Training Hub — Specs & Decisions

> Living document. Update whenever a feature is added, changed, or a decision is made.
> Last updated: 2026-03-27

---

## 1. Overview

**File:** `training-hub.html` (~4400 lines)
**Architecture:** Single-file HTML app — all HTML, CSS, and JavaScript in one file.
**Storage:** `localStorage` only. No backend, no network requests.
**Max width:** 700px (mobile-first, centred on desktop).

---

## 2. Tab Structure

| Tab | Nav label | ID |
|---|---|---|
| Gym | 💪 Gym | `tab-gym` |
| Climbing | 🧗 Climbing | `tab-climb` |
| Rehab | 🦵 Rehab | `tab-rehab` |
| Planner | 📅 Planner | `tab-plan` |

### Gym sub-modes
`log` · `build` · `history` · `progress` · `finger` (Fingerboard)

### Climbing sub-views
Log session · History · Pyramid · Assessments

### Planner sub-views
**Weekly** (default) · **Monthly** (toggle at top of tab)

---

## 3. Data Layer — `DB` Object

All data stored in `localStorage`. Key accessors:

```js
DB.gymSessions()         // → array of gym session objects
DB.saveGym(s)            // prepend new gym session
DB.updateGym(s)          // update existing (match by id)

DB.climbSessions()       // → array of climb session objects
DB.saveClimb(s)
DB.updateClimb(s)

DB.fbSessions()          // → array of fingerboard session objects
DB.saveFB(s)
DB.updateFB(s)

DB.planData()            // → object keyed by monday date (YYYY-MM-DD)
DB.savePlan(data)

DB.gymTemplates()        // saved gym workout templates
DB.fbTemplates()         // saved fingerboard templates
```

---

## 4. Climbing Session Formats

Three legacy formats exist. **Always use `getSessionRoutes(s)`** to normalise — never read routes directly.

### Format A — `s.routes[]` (oldest)
```js
{ routes: [ { grade, result, movements, climbedDown }, … ] }
```

### Format B — `s.blocks[].entries[]`
```js
{ blocks: [ { type:'routes', entries: [ { grade, result, count, movements, climbedDown }, … ] } ] }
```

### Format C — `s.blocks[].phases` (current)
```js
{ blocks: [ { type:'routes', phases: { warmup:[], main:[], cooldown:[] } } ] }
```
Each phase entry: `{ grade, result, count, movements, climbedDown }`

### `getSessionRoutes(s)` — normalised output
Returns a flat array of route objects, one per climb (count is expanded):
```js
{ grade, result, movements, climbedDown }
```
- `result` is normalised via `normResult()` → always capitalised (`'OS'`, `'Flash'`, `'RP'`, `'Repeat'`, `'Project'`)
- `movements` defaults to `0` if missing
- `climbedDown` defaults to `false` if missing

### `normResult(r)`
Maps lowercase/mixed → canonical: `'os'→'OS'`, `'flash'→'Flash'`, `'rp'→'RP'`, `'repeat'→'Repeat'`, `'project'→'Project'`

---

## 5. Constants

### `GYMS`
```js
{ "Neoliet": 13, "Neoliet (Outdoor)": 20, "Sterk": 4 }
```
Values are wall height in metres. Used for meter calculations. Custom wall height also supported (`s.wallHeight`).

**Priority:** `GYMS[s.gym] || s.wallHeight || 0`

### `CLIMB_GRADES`
```js
['3','4a','4b','4c','5a','5a+','5b','5b+','5c','5c+',
 '6a','6a+','6b','6b+','6c','6c+','7a','7a+','7b','7b+','8a']
```

### `PYRAMID` — targets for 2026
| Grade band | Bands | OS target | RP target | Status |
|---|---|---|---|---|
| 7b–7b+ | 7b, 7b+ | 0 | 1 | Project |
| 7a–7a+ | 7a, 7a+ | 1 | 2 | RP Target |
| 6c–6c+ | 6c, 6c+ | 2 | 4 | Build |
| 6b–6b+ | 6b, 6b+ | 4 | 8 | Solid base |
| 6a–6a+ | 6a, 6a+ | 8 | 16 | Warm-up |
| 5c–5c+ | 5c, 5c+ | 16 | 20 | Volume |
| 3–5b+ | 3…5b+ | — | — | Warm-up |

### `TRAINING_TYPES`
```js
{
  gym:    { icon:'💪', label:'Gym',      color:'#2ea043', subs:[…] },
  climb:  { icon:'🧗', label:'Climbing', color:'#388bfd', subs:[…] },
  tennis: { icon:'🎾', label:'Tennis',   color:'#a78bfa', subs:[…] },
  golf:   { icon:'⛳', label:'Golf',      color:'#34d399', subs:[…] },
  rehab:  { icon:'🦵', label:'Rehab',    color:'#f0883e', subs:[…] },
  active: { icon:'🏃', label:'Active',   color:'#8b949e', subs:[…] },
  rest:   { icon:'😴', label:'Rest',      color:'#484f58', subs:[…] },
}
```

---

## 6. Climbing Metrics — Calculation Rules

### Routes count
- Each route entry with `count: n` → adds `n` routes
- If `climbedDown: true` → counts **double** (up + down = 2 routes)
- Formula: `totalRoutes += n * (climbedDown ? 2 : 1)`

### Meters
- `meters = wallHeight * (climbedDown ? 2 : 1)` per route
- Wall height from `GYMS[s.gym] || s.wallHeight || 0`

### Movements
- Stored **per route** (e.g. 15 mv/rt)
- Total = `movements × count × (climbedDown ? 2 : 1)`
- Average = total movements ÷ number of routes with movements data

### Sends
- OS, Flash, RP = sends
- Repeat, Project = **not** sends — even if climbedDown
- **Decision:** a Project climbed down still counts for route count + movements, but never as a send

### Grade template (`climbBlocks`)
In-memory array `climbBlocks[]` holds live session blocks. Phases: `warmup`, `main`, `cooldown`.

---

## 7. Key Functions

| Function | Purpose |
|---|---|
| `getSessionRoutes(s)` | Normalise all 3 formats → flat route array |
| `normResult(r)` | Normalise result casing to canonical form |
| `gradeToBand(grade)` | Map grade string → pyramid band label |
| `updateClimbSummary()` | Recalculate live session stats (routes, meters, movements) |
| `renderClimbHistory()` | Render history cards with full metrics |
| `renderPyramid()` | Aggregate all sessions per grade band, show totals |
| `renderWeekTotals(weekStart)` | Week totals widget (gym + climb + FB + planner sports) |
| `renderPlanner()` | Weekly planner renderer |
| `switchPlannerView(view)` | Toggle between 'weekly' and 'monthly' planner views |
| `renderMonthlyResume()` | Full monthly analytics with trend chart + heatmaps |
| `editClimbSession(id)` | Load session into edit mode; migrates Format B → C |
| `updateWallHeight()` | Update wall height selector + trigger live summary refresh |
| `fmtMins(m)` | Format minutes → '1h 30min' etc. |
| `addDays(d, n)` | Add n days to a YYYY-MM-DD string |
| `getMonday(d)` | Get Monday of the week containing date d |

---

## 8. Planner Data Structure

```js
planData = {
  'YYYY-MM-DD': [   // key = Monday of that week
    {               // 7 day objects
      day: 'Monday',
      date: 'YYYY-MM-DD',
      done: false,
      work: false,
      workStart: '10:00',
      workEnd: '18:00',
      sessions: [
        {
          trainingType: 'climb',   // key of TRAINING_TYPES
          trainingSubtype: '...',
          duration: '90',          // minutes string
          rpe: '7',
          actual: 'free text notes'
        }
      ]
    },
    …
  ]
}
```

**Migration notes:**
- Old flat format (`trainingType` on day object) → migrated to `sessions[]` array on load
- Each day supports up to 3 sessions
- Work days: session[0] = before work, sessions[1+] = after work

---

## 9. Monthly Resume Feature

Located in **Planner → Monthly** toggle.

### Trend chart
- Stacked bars, one per month (oldest → newest, max 12 months)
- Each bar = total training minutes, segmented by activity type
- Colour coding: Climbing=#388bfd · Gym=#2ea043 · FB=#7c3aed · Tennis=#a78bfa · Golf=#34d399 · Active=#8b949e
- Current month highlighted with subtle outline

### Activity heatmap (per month card)
- 7-column grid (Mon → Sun), one square per day
- **Colour = intensity level** (not activity type — activity visible in tooltip)

| Intensity | Colour | Activities | Visual |
|---|---|---|---|
| High | Blood orange `#e8541c` | Climbing, Gym, Fingerboard | Solid inner white ring |
| Medium | Mustard `#c9960e` | Tennis, Active | Dashed inner outline |
| Low | Mint `#2dd4bf` | Golf, Rehab | Plain square |

- Past rest days: faint border dot
- Future days: empty
- Today: white outer glow ring
- Tooltip on hover: `YYYY-MM-DD: Activity1 + Activity2`

### Per-month metrics
- **Climbing:** sessions, time, routes, sends + send%, meters, movements, avg mv/rt, top grade (OS/Flash/RP)
- **Gym:** sessions, time, volume (kg/tonnes)
- **Fingerboard:** sessions, time
- **Other activity:** Tennis, Golf, Active, Rehab sessions + time (sourced from Planner entries)
- **Month overview:** total sessions, total time, active days / total days + density bar

### Month-over-month deltas
Shown inline next to each metric: `▲X%` (green) / `▼X%` (red) / `→` (stable, <1% change).
Comparison is always against the immediately preceding calendar month.

---

## 10. Bugs Fixed (history)

| Bug | Fix |
|---|---|
| Edit route modal left-column clipping | Added `overflow-x:hidden` to `.modal` |
| "Climbed down" label clipped | Moved to standalone pill row with `flex-shrink:0` on checkbox |
| `cooldown:{}` not iterable | Changed to `cooldown:[]` in `renderClimbBlocks` |
| Movements not shown in pyramid | Moved movements accumulation outside OS/RP filter |
| Pyramid wall height wrong | Added `GYMS[s.gym]` lookup before `s.wallHeight` |
| Week totals meters mismatch | Changed to `routes.forEach(r => climbMeters += wallH*(r.climbedDown?2:1))` |
| Projects counted as sends when downclimbed | Removed `\|\| e.climbedDown` clause from sends condition |
| Movements total wrong (doubled for downclimb) | Applied `mult = n*(climbedDown?2:1)` to movements total |
| Routes count missing downclimbs | Added `downclimbs` count to `totalRouteCount` in history card |
| Wall height not updating live summary | Added `updateClimbSummary()` call to `updateWallHeight()` |
| Format B entries missing `climbedDown` | Fixed in `getSessionRoutes` to default `climbedDown:false` |
| Result casing mismatch (`'project'` vs `'Project'`) | `normResult()` helper centralises normalisation |
| Format B not migrated on edit | `editClimbSession()` now migrates `entries[]` → `phases` |
| Old `s.routes[]` not normalising result on edit | `normResult()` applied in `getSessionRoutes` for all formats |

---

## 11. UI / Design Decisions

- **Dark theme only.** CSS variables: `--bg`, `--surface`, `--surface2`, `--border`, `--text`, `--muted`, `--muted2`
- **Activity colours:** gym=`#2ea043` · climb=`#388bfd` · rehab=`#f0883e` · fb=`#7c3aed`
- **Movements field label:** `Mvs/rt` (per-route, not total) — clarified in both inline row and modal
- **Down-climbing:** Significant training effort — counted in routes, meters, movements. Not counted as a send for Projects (even if downclimbed).
- **Pyramid:** Shows total movements per grade band (not average), plus a totals row. All result types (incl. Repeat/Project) contribute to movements.
- **Session detail view:** Stats bar (routes, sends, meters, movements) + mv/rt shown per route
- **Monthly view:** Most recent month expanded by default; older months collapsed.
- **Heatmap intensity palette:** User-chosen warm→cool spectrum (orange=hard, mustard=medium, mint=easy) rather than activity-type colours — more intuitive at a glance.

---

## 12. File Structure (notable sections)

| Lines (approx.) | Content |
|---|---|
| 1–230 | `<style>` — all CSS |
| 231–600 | HTML structure — all tab panels + modals |
| 601–950 | Constants (`SUGGESTED_WEIGHTS`, `GYMS`, `PYRAMID`, `TRAINING_TYPES`, etc.) |
| 950–1140 | `DB` object + utility functions |
| 1140–1160 | Tab navigation (`switchTab`) |
| 1160–1920 | Gym tab logic |
| 1920–2270 | Gym history + progress |
| 2270–2640 | Climbing session log + templates |
| 2640–2800 | Climbing history + pyramid |
| 2800–3250 | Climbing session detail + edit modal |
| 3250–3470 | Planner week totals widget |
| 3470–3740 | Monthly Resume (`switchPlannerView`, `renderMonthlyResume`) |
| 3740–3870 | Weekly planner (`renderPlanner` and helpers) |
| 3870–4414 | Fingerboard tab (log, build, templates, history, progress) |
