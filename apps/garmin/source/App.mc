// ============================================================
// App.mc — Application Entry Point
// Garmin Tennis Tracker for Vivoactive 6
// ============================================================
// This is the first file Garmin runs when your app launches.
// It creates the initial screen (SetupView) and starts the app.
// ============================================================

using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Lang;
using Toybox.Timer;

// TennisApp is the main application class.
// Garmin calls onStart() automatically when the app opens.
class TennisApp extends App.AppBase {

    // v1.3.7: hold the SupabaseSync instance created at startup so its
    // callback reference stays alive while the HTTP request is in-flight.
    var _startupSync;

    // v1.3.10: hold TennisActivityManager during a match upload so it
    // is not garbage-collected before onResponse() fires.
    var _matchSync;

    // v1.3.10: timer used to defer the startup retry until after the app
    // is fully initialised (makeWebRequest cannot fire during getInitialView).
    var _retryTimer;

    function initialize() {
        AppBase.initialize();
        _startupSync = null;
        _matchSync   = null;
        _retryTimer  = null;
    }

    // v1.3.10: schedule the pending-upload retry here (after view stack is
    // ready) rather than inside getInitialView() where the Communications
    // layer is not yet available and makeWebRequest returns -200.
    function onStart(state) {
        if (MatchPersistence.firstPendingSlot() >= 0) {
            _retryTimer = new Timer.Timer();
            _retryTimer.start(method(:retryPendingUpload), 2000, false);
        }
    }

    // Timer callback — fires 2 s after app start.
    // By this point the view is rendered and makeWebRequest is allowed.
    function retryPendingUpload() as Void {
        _retryTimer = null;
        retryNextPending();
    }

    // v1.4.8: processes the FIRST pending queue slot. Chained from
    // SupabaseSync.onResponse() on each success, so multiple stuck
    // matches drain one by one while connectivity is good. Stops on
    // the first failure (payloads stay queued for next time).
    function retryNextPending() as Void {
        var slot = MatchPersistence.firstPendingSlot();
        if (slot < 0) {
            _startupSync = null;   // queue empty — release GC anchor
            return;
        }
        try {
            var state = MatchPersistence.loadSlot(slot);
            if (state == null) {
                MatchPersistence.clearSlot(slot);
                return;
            }
            var config = {
                :matchFormat           => state.hasKey("matchFormat") ? state["matchFormat"] : 0,
                :setsToWin             => state["setsToWin"],
                :tiebreakEnabled       => state["tbEnabled"],
                :superTiebreakFinalSet => state["superTBFinal"]
            };
            var engine = new TennisMatchEngine(config);
            engine.restore(state);
            _startupSync = new SupabaseSync();
            _startupSync.setSlot(slot);
            _startupSync.uploadMatch(engine, null);
        } catch (ex instanceof Lang.Exception) {
            // Corrupted or stale payload — drop this slot so it
            // doesn't block the rest of the queue.
            MatchPersistence.clearSlot(slot);
        }
    }

    // Called when the app stops (user exits or watch powers down).
    function onStop(state) {
        // Nothing to clean up here — MatchPersistence handles saving.
    }

    // Required by Connect IQ — returns the initial view and delegate.
    function getInitialView() {
        // ── Resume prompt or fresh setup ──────────────────────
        // v1.3.7: skip the resume prompt for completed matches
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
