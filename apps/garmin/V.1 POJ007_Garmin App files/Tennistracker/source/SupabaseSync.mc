// ============================================================
// SupabaseSync.mc — POST match results to Supabase
// MatchMind Tennis Tracker for Garmin Vivoactive 6
// ============================================================
// v1.2: at match end, builds a JSON payload from the engine
// state and POSTs it to the `matches` table via Supabase's REST
// API. Credentials live in Secrets.mc; the watch needs internet
// (via paired phone or WiFi) for the POST to succeed. Failures
// are logged but don't block the activity from saving locally.
//
// Garmin's Communications.makeWebRequest callback must be a
// method on the same class instance, so SupabaseSync is a class
// (not a module). TennisActivityManager holds an instance and
// calls uploadMatch(engine) inside stopSession().
// ============================================================

using Toybox.Communications as Comm;
using Toybox.System as Sys;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Lang;

class SupabaseSync {

    function initialize() {
    }

    // ─────────────────────────────────────────────────────────
    // uploadMatch(engine, manager)
    // Builds the JSON payload and POSTs it. Non-blocking — the
    // response handler just prints to the simulator log.
    // ─────────────────────────────────────────────────────────
    function uploadMatch(engine, manager) {
        if (engine == null) { return; }

        var url = Secrets.SUPABASE_URL + "/rest/v1/matches";

        var headers = {
            "Content-Type"  => "application/json",
            "apikey"        => Secrets.SUPABASE_ANON_KEY,
            "Authorization" => "Bearer " + Secrets.SUPABASE_ANON_KEY,
            "Prefer"        => "return=minimal"
        };

        var body = buildPayload(engine, manager);

        Sys.println("SupabaseSync: POST " + url);

        Comm.makeWebRequest(
            url,
            body,
            {
                :method       => Comm.HTTP_REQUEST_METHOD_POST,
                :headers      => headers,
                :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onResponse)
        );
    }

    // ─────────────────────────────────────────────────────────
    // onResponse(responseCode, data)
    // Strict type annotations required by Monkey C 9.x for the
    // Communications.makeWebRequest callback signature.
    // ─────────────────────────────────────────────────────────
    function onResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        if (responseCode == 200 || responseCode == 201 || responseCode == 204) {
            Sys.println("SupabaseSync: OK (" + responseCode + ")");
        } else {
            Sys.println("SupabaseSync: FAILED code=" + responseCode + " data=" + data);
        }
    }

    // ─────────────────────────────────────────────────────────
    // buildPayload(engine, manager)
    // ─────────────────────────────────────────────────────────
    function buildPayload(engine, manager) {
        // Aggregate games across all completed sets + current set
        var totalGamesP = engine.player[:games];
        var totalGamesO = engine.opponent[:games];
        if (engine.setHistory != null) {
            for (var i = 0; i < engine.setHistory.size(); i++) {
                var entry = engine.setHistory[i];
                totalGamesP += entry[:p];
                totalGamesO += entry[:o];
            }
        }

        var durationMs = Sys.getTimer() - engine.startTime;
        var durationSec = durationMs / 1000;

        var hrAvg = null;
        var hrMax = null;
        // HR is best-effort: only included if the activity manager
        // has them. (We don't always have these on demand.)

        var payload = {
            "match_date"           => formatTimestampUtc(),
            "match_type"           => engine.matchType,
            "format"               => formatPresetString(engine),
            "result"               => matchResult(engine),
            "duration_sec"         => durationSec,
            "final_score"          => buildFinalScore(engine),
            "set_scores"           => buildSetScoresJson(engine),
            "sets_won"             => engine.player[:sets],
            "sets_lost"            => engine.opponent[:sets],
            "points_won"           => engine.player[:winners],
            "unforced_errors"      => engine.player[:unforcedErrors],
            "double_faults"        => engine.player[:doubleFaults],
            "service_points_won"   => engine.player[:servePtsWon],
            "return_points_won"    => engine.player[:returnPtsWon],
            "total_games_won"      => totalGamesP,
            "total_games_lost"     => totalGamesO,
            "tiebreaks_won"        => engine.player[:tiebreaksWon],
            "tiebreak_points_won"  => engine.player[:tiebreakPointsWon],
            "tiebreak_points_lost" => engine.player[:tiebreakPointsLost],
            "hr_avg"               => hrAvg,
            "hr_max"               => hrMax,
            "player_served_first"  => engine.playerServing  // best approximation
        };

        return payload;
    }

    // ─────────────────────────────────────────────────────────
    // matchResult(engine) → "won" / "lost" / "abandoned"
    // ─────────────────────────────────────────────────────────
    function matchResult(engine) {
        if (!engine.matchOver) { return "abandoned"; }
        if (engine.player[:sets] > engine.opponent[:sets]) { return "won"; }
        return "lost";
    }

    // ─────────────────────────────────────────────────────────
    // formatPresetString(engine) → "best_of_3" / "doubles_compact"
    //   / "single_set" / "super_tb"
    // ─────────────────────────────────────────────────────────
    function formatPresetString(engine) {
        if (engine.matchFormat == 2) { return "super_tb"; }
        if (engine.matchFormat == 1) { return "tiebreak"; }
        // matchFormat == 0 (Sets)
        if (engine.setsToWin == 1)   { return "single_set"; }
        if (engine.superTiebreakFinalSet) { return "doubles_compact"; }
        return "best_of_3";
    }

    // ─────────────────────────────────────────────────────────
    // buildFinalScore(engine) → "6-4, 7-6" style string
    // ─────────────────────────────────────────────────────────
    function buildFinalScore(engine) {
        if (engine.setHistory == null || engine.setHistory.size() == 0) {
            return "";
        }
        var parts = "";
        for (var i = 0; i < engine.setHistory.size(); i++) {
            var s = engine.setHistory[i];
            if (i > 0) { parts += ", "; }
            parts += s[:p].toString() + "-" + s[:o].toString();
        }
        return parts;
    }

    // ─────────────────────────────────────────────────────────
    // buildSetScoresJson(engine) → jsonb array of {p,o} objects
    // The Comm layer serializes Dict → JSON automatically.
    // ─────────────────────────────────────────────────────────
    function buildSetScoresJson(engine) {
        var arr = [];
        if (engine.setHistory == null) { return arr; }
        for (var i = 0; i < engine.setHistory.size(); i++) {
            var s = engine.setHistory[i];
            arr.add({ "p" => s[:p], "o" => s[:o] });
        }
        return arr;
    }

    // ─────────────────────────────────────────────────────────
    // formatTimestampUtc() → ISO 8601 string for Supabase
    // Falls back to current time if Time module unavailable.
    // ─────────────────────────────────────────────────────────
    function formatTimestampUtc() {
        var info = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        var s = info.year.toString() + "-" +
                pad2(info.month) + "-" +
                pad2(info.day) + "T" +
                pad2(info.hour) + ":" +
                pad2(info.min) + ":" +
                pad2(info.sec) + "Z";
        return s;
    }

    function pad2(n) {
        if (n < 10) { return "0" + n.toString(); }
        return n.toString();
    }
}
