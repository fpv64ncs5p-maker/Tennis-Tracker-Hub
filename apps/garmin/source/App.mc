// ============================================================
// App.mc — Application Entry Point
// Garmin Tennis Tracker for Vivoactive 6
// ============================================================
// This is the first file Garmin runs when your app launches.
// It creates the initial screen (SetupView) and starts the app.
// ============================================================

using Toybox.Application as App;
using Toybox.WatchUi as Ui;

// TennisApp is the main application class.
// Garmin calls onStart() automatically when the app opens.
class TennisApp extends App.AppBase {

    // v1.3.7: hold the SupabaseSync instance created at startup so its
    // callback reference stays alive while the HTTP request is in-flight.
    var _startupSync;

    function initialize() {
        AppBase.initialize();
        _startupSync = null;
    }

    // Called when the app starts — nothing to do here,
    // getInitialView() handles the first screen.
    function onStart(state) {
    }

    // Called when the app stops (user exits or watch powers down).
    function onStop(state) {
        // Nothing to clean up here — MatchPersistence handles saving.
    }

    // Required by Connect IQ — returns the initial view and delegate.
    // v1.3.7: on startup, checks for any match data that wasn't uploaded
    // in the previous session (e.g. OS-intercepted exit, mid-match save)
    // and retries the Supabase POST silently in the background.
    function getInitialView() {
        // ── v1.3.8: retry any pending Supabase upload ─────────
        // Uses a dedicated payload key that survives clearState() —
        // so retries work even when the match ended normally via
        // finishAndExit (which wipes the resume state but not this key).
        if (MatchPersistence.hasSupabasePayload()) {
            var state = MatchPersistence.loadSupabasePayload();
            if (state != null) {
                var config = {
                    :matchFormat           => state.hasKey("matchFormat") ? state["matchFormat"] : 0,
                    :setsToWin             => state["setsToWin"],
                    :tiebreakEnabled       => state["tbEnabled"],
                    :superTiebreakFinalSet => state["superTBFinal"]
                };
                var engine = new TennisMatchEngine(config);
                engine.restore(state);
                _startupSync = new SupabaseSync();
                _startupSync.uploadMatch(engine, null);
            }
        }

        // ── Resume prompt or fresh setup ──────────────────────
        // v1.3.7: also skip the resume prompt for completed matches
        // (matchOver = true) — no point resuming a finished game.
        if (MatchPersistence.hasSavedState()) {
            var state = MatchPersistence.loadState();
            if (state != null && state.hasKey("matchOver") && state["matchOver"]) {
                // Match was over but app exited before clearState() ran.
                // Nothing to resume — clear and go to setup.
                MatchPersistence.clearState();
            } else {
                var promptView = new ResumePromptView();
                return [promptView, new ResumePromptDelegate(promptView)];
            }
        }

        var setupView = new SetupView();
        return [setupView, new SetupDelegate(setupView)];
    }
}
