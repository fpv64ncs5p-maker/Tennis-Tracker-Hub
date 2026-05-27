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

    // Called when the app starts — nothing to do here,
    // getInitialView() handles the first screen.
    function onStart(state) {
    }

    // Called when the app stops (user exits or watch powers down).
    function onStop(state) {
        // Nothing to clean up here — MatchPersistence handles saving.
    }

    // Required by Connect IQ — returns the initial view and delegate.
    // If a match was in progress when the app closed, show resume prompt.
    function getInitialView() {
        // Pass the View by reference to its delegate. This replaces the
        // unreliable Ui.getCurrentView()[0] pattern that crashed (IQ! icon)
        // on real watches in v1.1.1.
        if (MatchPersistence.hasSavedState()) {
            var promptView = new ResumePromptView();
            return [promptView, new ResumePromptDelegate(promptView)];
        }
        var setupView = new SetupView();
        return [setupView, new SetupDelegate(setupView)];
    }
}
