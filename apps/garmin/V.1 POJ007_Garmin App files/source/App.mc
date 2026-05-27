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

    function initialize() {
        AppBase.initialize();
    }

    // Called when the app starts.
    // We show the SetupView first so the player can configure the match.
    function onStart(state) {
        Ui.pushView(
            new SetupView(),
            new SetupDelegate(),
            Ui.SLIDE_IMMEDIATE
        );
    }

    // Called when the app stops (user exits or watch powers down).
    function onStop(state) {
        // Nothing to clean up here — MatchPersistence handles saving.
    }

    // Required by Connect IQ — returns the initial view.
    function getInitialView() {
        return [new SetupView(), new SetupDelegate()];
    }
}
