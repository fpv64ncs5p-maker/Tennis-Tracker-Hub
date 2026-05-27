// ============================================================
// MatchPersistence.mc — Save & Load Match State
// Garmin Tennis Tracker for Vivoactive 6
// ============================================================
// This module handles saving match state to the watch's storage
// so that if the app is closed mid-match (watch sleeps, button
// pressed accidentally), the player can resume where they left off.
//
// Uses Toybox.Storage — a simple key-value store on the watch.
// Data survives app restarts but is cleared after the match ends.
//
// HOW IT WORKS:
//   1. After every point, MainView calls saveState()
//   2. When the app starts, it checks for a saved state
//   3. If found, it shows "Resume match?" prompt
//   4. If yes, engine.restore(state) loads everything back
// ============================================================

using Toybox.Application.Storage as Storage;

// MatchPersistence uses only static (module-level) functions.
// No instance needed — call as MatchPersistence.saveState(engine) etc.
module MatchPersistence {

    // Storage key — the string used to look up saved data.
    const STORAGE_KEY = "tennis_match_state";

    // ─────────────────────────────────────────────────────────
    // saveState(engine)
    // Serializes the engine's full state and writes it to storage.
    // Call this after every point (in MainView after handleInput).
    // ─────────────────────────────────────────────────────────
    function saveState(engine) {
        var state = engine.getState(); // Returns a flat dictionary
        Storage.setValue(STORAGE_KEY, state);
    }

    // ─────────────────────────────────────────────────────────
    // hasSavedState()
    // Returns true if there is a match saved that can be resumed.
    // Called on app startup to decide whether to show the resume prompt.
    // ─────────────────────────────────────────────────────────
    function hasSavedState() {
        var state = Storage.getValue(STORAGE_KEY);
        return (state != null);
    }

    // ─────────────────────────────────────────────────────────
    // loadState()
    // Returns the saved state dictionary, or null if nothing saved.
    // Use engine.restore(state) to apply it.
    // ─────────────────────────────────────────────────────────
    function loadState() {
        return Storage.getValue(STORAGE_KEY);
    }

    // ─────────────────────────────────────────────────────────
    // clearState()
    // Deletes the saved match from storage.
    // Call this when the match ends normally.
    // ─────────────────────────────────────────────────────────
    function clearState() {
        Storage.deleteValue(STORAGE_KEY);
    }
}


// ============================================================
// ResumePromptView.mc (included in this file for convenience)
// ============================================================
// A simple yes/no dialog shown at startup if a saved match exists.
// "Resume match?" → YES loads the match, NO starts fresh.
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;

class ResumePromptView extends Ui.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, h);

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 50, Gfx.FONT_SMALL, "Resume match?", Gfx.TEXT_JUSTIFY_CENTER);

        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 20, Gfx.FONT_XTINY, "A match was in progress", Gfx.TEXT_JUSTIFY_CENTER);

        // YES button
        dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_DK_GREEN);
        dc.fillRoundedRectangle(w / 2 - 80, h / 2 + 10, 70, 36, 8);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2 - 45, h / 2 + 18, Gfx.FONT_SMALL, "YES", Gfx.TEXT_JUSTIFY_CENTER);

        // NO button
        dc.setColor(Gfx.COLOR_DK_RED, Gfx.COLOR_DK_RED);
        dc.fillRoundedRectangle(w / 2 + 10, h / 2 + 10, 70, 36, 8);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + 45, h / 2 + 18, Gfx.FONT_SMALL, "NO", Gfx.TEXT_JUSTIFY_CENTER);
    }

    function onShow() {}
    function onHide() {}
}

class ResumePromptDelegate extends Ui.InputDelegate {

    function initialize() {
        InputDelegate.initialize();
    }

    function onTap(clickEvent) {
        var coords = clickEvent.getCoordinates();
        var x      = coords[0];
        var y      = coords[1];

        // Determine screen width (approximation for Vivoactive 6)
        var w = 390;
        var h = 450;

        var btnY    = h / 2 + 10;
        var btnH    = 36;

        if (y >= btnY && y <= btnY + btnH) {
            if (x < w / 2) {
                // YES — resume
                resumeMatch();
            } else {
                // NO — start fresh
                MatchPersistence.clearState();
                newMatch();
            }
        }
        return true;
    }

    function resumeMatch() {
        var state  = MatchPersistence.loadState();
        var config = {
            :setsToWin             => state[:setsToWin],
            :tiebreakEnabled       => state[:tiebreakEnabled],
            :superTiebreakFinalSet => state[:superTiebreakFinalSet]
        };
        var engine = new TennisMatchEngine(config);
        engine.restore(state);

        Ui.switchToView(
            new MainView(engine),
            new MainDelegate(engine),
            Ui.SLIDE_IMMEDIATE
        );
    }

    function newMatch() {
        Ui.switchToView(
            new SetupView(),
            new SetupDelegate(),
            Ui.SLIDE_IMMEDIATE
        );
    }
}
