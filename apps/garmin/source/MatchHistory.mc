// ============================================================
// MatchHistory.mc — Persistent Match History
// MatchMind Tennis Tracker for Vivoactive 6
// ============================================================
// v1.3: saves the last 5 completed matches to Toybox.Storage.
// Each record stores: result, set scores, points won/lost,
// errors, double faults, date, and match type.
//
// Storage keys (flat, primitives only — same rules as MatchPersistence):
//   "histCount"          — number of saved matches (0-5)
//   "hN_won"             — 1 = player won, 0 = opponent won
//   "hN_setsP"           — player sets won
//   "hN_setsO"           — opponent sets won
//   "hN_sets"            — set scores string e.g. "6-3 4-6 7-5"
//   "hN_ptsW"            — player points won (winners)
//   "hN_ptsL"            — player points lost (errors + DFs)
//   "hN_err"             — player unforced errors
//   "hN_df"              — player double faults
//   "hN_date"            — unix timestamp (Time.now().value())
//   "hN_mtype"           — "singles" or "doubles"
// (N = 0 is most recent, N = 4 is oldest)
// ============================================================

using Toybox.Application.Storage as Storage;
using Toybox.Time;

module MatchHistory {

    const MAX = 5;

    // ─────────────────────────────────────────────────────────
    // saveMatch(engine)
    // Shifts existing records down one slot and writes the new
    // match at index 0. Called from PostMatchDelegate before
    // clearing the match state.
    // ─────────────────────────────────────────────────────────
    function saveMatch(engine) {
        if (engine == null) { return; }

        var count = Storage.getValue("histCount");
        if (count == null) { count = 0; }

        // Keep at most MAX records — shift 0→1, 1→2, etc.
        var newCount = (count < MAX) ? count + 1 : MAX;
        var i = newCount - 1;
        while (i > 0) {
            _copyRecord(i - 1, i);
            i -= 1;
        }

        _writeRecord(0, engine);
        Storage.setValue("histCount", newCount);
    }

    // ─────────────────────────────────────────────────────────
    // getCount() — how many matches are stored
    // ─────────────────────────────────────────────────────────
    function getCount() {
        var c = Storage.getValue("histCount");
        return (c != null) ? c : 0;
    }

    // ─────────────────────────────────────────────────────────
    // getMatch(idx) — returns a String-keyed dict for match idx
    // ─────────────────────────────────────────────────────────
    function getMatch(idx) {
        var p = "h" + idx.toString() + "_";
        return {
            "won"   => Storage.getValue(p + "won"),
            "setsP" => Storage.getValue(p + "setsP"),
            "setsO" => Storage.getValue(p + "setsO"),
            "sets"  => Storage.getValue(p + "sets"),
            "ptsW"  => Storage.getValue(p + "ptsW"),
            "ptsL"  => Storage.getValue(p + "ptsL"),
            "err"   => Storage.getValue(p + "err"),
            "df"    => Storage.getValue(p + "df"),
            "date"  => Storage.getValue(p + "date"),
            "mtype" => Storage.getValue(p + "mtype")
        };
    }

    // ─────────────────────────────────────────────────────────
    // deleteMatch(idx)
    // Removes the match at idx, shifting newer records up to fill
    // the gap, and decrements histCount.
    // ─────────────────────────────────────────────────────────
    function deleteMatch(idx) {
        var count = getCount();
        if (count == 0 || idx < 0 || idx >= count) { return; }

        // Shift records above idx down by one slot
        for (var i = idx; i < count - 1; i++) {
            _copyRecord(i + 1, i);
        }

        // Clear the now-duplicate top slot
        var newCount = count - 1;
        var p = "h" + newCount.toString() + "_";
        var keys = ["won", "setsP", "setsO", "sets", "ptsW", "ptsL", "err", "df", "date", "mtype"];
        for (var i = 0; i < keys.size(); i++) {
            Storage.deleteValue(p + keys[i]);
        }

        Storage.setValue("histCount", newCount);
    }

    // ── Private helpers ───────────────────────────────────────

    function _writeRecord(idx, engine) {
        var p         = "h" + idx.toString() + "_";
        var playerWon = (engine.player[:sets] >= engine.setsToWin) ? 1 : 0;

        // Build set-score string e.g. "6-3 4-6"
        var setStr = "";
        if (engine.setHistory != null) {
            for (var i = 0; i < engine.setHistory.size(); i++) {
                if (i > 0) { setStr = setStr + " "; }
                var entry = engine.setHistory[i];
                setStr = setStr + entry[:p].toString() + "-" + entry[:o].toString();
            }
        }

        var mtype = (engine.matchType != null) ? engine.matchType : "singles";

        Storage.setValue(p + "won",   playerWon);
        Storage.setValue(p + "setsP", engine.player[:sets]);
        Storage.setValue(p + "setsO", engine.opponent[:sets]);
        Storage.setValue(p + "sets",  setStr);
        Storage.setValue(p + "ptsW",  engine.player[:winners]);
        Storage.setValue(p + "ptsL",  engine.player[:unforcedErrors] + engine.player[:doubleFaults]);
        Storage.setValue(p + "err",   engine.player[:unforcedErrors]);
        Storage.setValue(p + "df",    engine.player[:doubleFaults]);
        Storage.setValue(p + "date",  Time.now().value());
        Storage.setValue(p + "mtype", mtype);
    }

    function _copyRecord(fromIdx, toIdx) {
        var f    = "h" + fromIdx.toString() + "_";
        var t    = "h" + toIdx.toString() + "_";
        var keys = ["won", "setsP", "setsO", "sets", "ptsW", "ptsL", "err", "df", "date", "mtype"];
        for (var i = 0; i < keys.size(); i++) {
            Storage.setValue(t + keys[i], Storage.getValue(f + keys[i]));
        }
    }
}
