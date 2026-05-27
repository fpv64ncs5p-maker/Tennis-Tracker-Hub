# Training Hub — ACSM-Based Improvement Ideas
*Generated: 2026-04-02 | Source: ACSM Resources for the Personal Trainer, 5th Edition*

---

## What the ACSM docs cover

The screenshots capture the full ACSM PT study guide: session structure, FITT-VP principles, periodization, resistance/cardio/flexibility/neuromotor training, advanced techniques (plyometrics, speed/agility), special populations (older adults, obesity, diabetes, hypertension), body composition, nutrition basics, and a full sequence of fitness assessments.

---

## Gap Analysis — What the app is missing vs ACSM standards

### 1. Gym: Session Goal / Training Phase
**ACSM principle:** Muscular Strength, Hypertrophy, Power, and Endurance each require distinct FITT-VP parameters (different % 1RM, rep ranges, rest periods, volume).

**Current state:** Gym sessions are logged without a declared goal. No way to tell from history whether a session was a strength day vs a hypertrophy day.

**Suggestion:** Add a **Session Goal** field to the Gym log: `Strength · Hypertrophy · Power · Endurance · General`. This unlocks filtered progress views and future recommendations (e.g. "For Hypertrophy: 8–12 reps at 70–85% 1RM").

---

### 2. Gym: RPE per session
**ACSM principle:** Training intensity is a core acute variable and should be tracked on every session (alongside volume).

**Current state:** RPE exists in the Planner but is not captured in the Gym log itself. Gym history has no intensity signal.

**Suggestion:** Add an **RPE field (1–10)** to the Gym session save form — same pattern as the Planner already uses.

---

### 3. Gym: Progressive Overload tracker
**ACSM principle:** "Progressive overload — the systematic increase in frequency, volume, and intensity — is required for further adaptations." Stagnation = no stimulus.

**Current state:** The app stores full session history but doesn't surface stagnation. No alert or indicator when a lift hasn't progressed.

**Suggestion:** In Gym History or Progress, flag exercises where weight × reps hasn't increased in the last 3+ sessions. A subtle "📈 No progress recently" badge on the exercise in the progress chart would be enough.

---

### 4. Gym: Periodization / Phase tracker
**ACSM principle:** Periodization (macro → meso → micro) prevents overtraining and ensures progressive adaptation. Linear model: Hypertrophy → Strength → Power → Peaking → Deload.

**Current state:** Climbing has a full 6-phase macrocycle tracker. Gym has nothing equivalent. Jo's gym sessions have no phase context.

**Suggestion:** Add a **Gym Macrocycle tab** (mirroring the Climbing Macro), with phases like: `Base/Hypertrophy → Strength → Power → Deload`. Aligning this with the climbing macro would help avoid conflicts (e.g. don't peak gym during climbing taper).

---

### 5. Flexibility / Stretching log
**ACSM principle:** Flexibility should be trained 2–3×/week, ≥10 min/session, targeting all major muscle-tendon groups. At least 60 seconds total per joint. Static, dynamic, and PNF techniques each have specific use cases.

**Current state:** Jo's training split includes "Rest/Stretching" days, but there is no log for stretching sessions. It's invisible in all analytics.

**Suggestion:** Add a **Stretching / Mobility session type** to the Planner (or a simple log in Rehab). Fields: duration, technique (Static / Dynamic / PNF), muscle groups targeted. This would make flexibility visible in the weekly totals and monthly summary.

---

### 6. Weekly Cardio Volume metric
**ACSM principle:** ≥150 min/week of moderate-intensity cardio, or ≥75 min vigorous, for health maintenance. Volume = ≥500 METs/week.

**Current state:** The weekly totals widget shows Gym, Climbing, and Fingerboard. Tennis, Golf, and Active sessions from the Planner are not aggregated into a cardio-minutes total.

**Suggestion:** Add a **Cardio minutes total** row to the Week Totals widget, pulling from Planner sessions tagged as Tennis, Golf, Active. Show a simple `X min / 150 min` progress indicator.

---

### 7. Body Composition panel
**ACSM principle:** Body composition should be tracked with Fat Weight (FW), Lean Body Weight (LBW), and Desired Body Weight (DBW). BMI is a secondary indicator.

**Current state:** The Gym log captures body weight, body fat %, and muscle mass. But these are raw inputs — no derived metrics or history chart.

**Suggestion:** Add a **Body Composition card** in Gym → Progress showing:
- BMI (with classification: Underweight / Acceptable / Overweight / Obese)
- Fat Weight = BW × BF%
- Lean Body Weight = BW − FW
- Trend chart of BW + BF% + muscle mass over time

---

### 8. Warm-up / Cool-down duration in Gym log
**ACSM principle:** Every session should include 5–10 min warm-up (low–moderate cardio + dynamic stretching) and 5–10 min cool-down (reduces CVD risk, aids recovery).

**Current state:** Climbing has Warm-up / Main / Cool-down phases built into session structure. Gym has no equivalent — it's pure exercises.

**Suggestion:** Add optional **Warm-up** and **Cool-down** duration fields (in minutes) at the top/bottom of the Gym log form. Simple, lightweight — just captures time. These would roll into total session duration.

---

### 9. Gym Fitness Assessments sub-tab
**ACSM principle:** Periodic reassessment is essential. ACSM recommends: HR, body composition, CRF (1.5-mile / Rockport walk), muscular strength (1RM bench press + leg press), muscular endurance (push-up test), flexibility (sit-and-reach).

**Current state:** Climbing has a Lattice Assessment sub-tab with progress arrows. Gym has no equivalent fitness testing record.

**Suggestion:** Add an **Assessments sub-tab in Gym** with manual entry for:
- 1RM (key lifts: squat, bench, deadlift, row)
- Push-up max reps
- Sit-and-reach (cm)
- Cardiorespiratory test result (Rockport walk time or 1.5-mile run time)
- Body composition (already in log, could be surfaced here)
Progress arrows comparing to previous assessment — same pattern as Lattice Assessment.

---

### 10. Rest period guidance (lightweight)
**ACSM principle:** Rest periods are an acute variable that must match training goal — 2–3 min for strength/power, 1–2 min for hypertrophy, <1 min for endurance.

**Current state:** No rest period tracking or guidance in the Gym log.

**Suggestion:** If Session Goal (idea #1) is implemented, show a **recommended rest period range** as a contextual hint near the exercise entry (e.g. "💡 Strength goal → rest 2–3 min between sets"). No need to log it — just a nudge.

---

## Priority ranking

| Priority | Feature | Effort | Impact |
|---|---|---|---|
| ⭐⭐⭐ | RPE per gym session | Low | High — fills a key data gap |
| ⭐⭐⭐ | Weekly cardio minutes total | Low | High — closes a visible blind spot |
| ⭐⭐⭐ | Body composition panel | Medium | High — data is already there |
| ⭐⭐ | Session Goal field | Low | Medium — enables future filtering |
| ⭐⭐ | Flexibility/stretching log | Medium | Medium — Jo has "stretching days" |
| ⭐⭐ | Gym Assessments sub-tab | Medium | Medium — mirrors Lattice pattern |
| ⭐ | Progressive overload flag | Medium | Medium — nice to have |
| ⭐ | Warm-up/cool-down duration | Low | Low — minor data point |
| ⭐ | Gym periodization macro | High | High long-term, but climbing macro first |
| ⭐ | Rest period guidance | Low | Low — informational only |

---

*All suggestions are options — nothing should be built without Jo's confirmation.*
