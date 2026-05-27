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
using Toybox.System as Sys;

// v1.1.2: responsive layout. Button bounds stored on the view so the
// delegate doesn't have to hardcode tap zones (this was already the
// May 5 fix, but the layout itself was still squished — buttons were
// 70×36 and packed against the hint text).
class ResumePromptView extends Ui.View {

    var btnY;
    var btnH;
    var yesX;
    var noX;
    var btnW;

    function initialize() {
        View.initialize();
        btnY = 0;
        btnH = 0;
        yesX = 0;
        noX  = 0;
        btnW = 0;
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, h);

        // Title and hint — well above the buttons
        var titleY = h * 28 / 100;
        var hintY  = titleY + dc.getFontHeight(Gfx.FONT_SMALL) + 4;

        // Buttons — bigger, with breathing room
        btnW       = w * 28 / 100;
        btnH       = h * 14 / 100;
        btnY       = h * 56 / 100;
        var gap    = w * 4 / 100;
        yesX       = w / 2 - btnW - gap / 2;
        noX        = w / 2 + gap / 2;

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, titleY, Gfx.FONT_SMALL, "Resume match?",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, hintY, Gfx.FONT_XTINY, "A match was in progress",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // YES button (green filled)
        dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_DK_GREEN);
        dc.fillRoundedRectangle(yesX, btnY, btnW, btnH, 10);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(yesX + btnW / 2, btnY + btnH / 2, Gfx.FONT_SMALL, "YES",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // NO button (red filled)
        dc.setColor(Gfx.COLOR_DK_RED, Gfx.COLOR_DK_RED);
        dc.fillRoundedRectangle(noX, btnY, btnW, btnH, 10);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(noX + btnW / 2, btnY + btnH / 2, Gfx.FONT_SMALL, "NO",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    function onShow() {}
    function onHide() {}
}

class ResumePromptDelegate extends Ui.InputDelegate {

    var view;

    function initialize(promptView) {
        InputDelegate.initialize();
        view = promptView;
    }

    function onTap(clickEvent) {
        if (view == null || view.btnH == 0) {
            return true;  // layout not yet computed
        }

        var coords = clickEvent.getCoordinates();
        var x      = coords[0];
        var y      = coords[1];
        var pad    = 8;

        // Tap must be within the button row vertically
        if (y < view.btnY - pad || y > view.btnY + view.btnH + pad) {
            return true;
        }

        // YES on the left, NO on the right — use the view's stored x bounds
        if (x >= view.yesX - pad && x <= view.yesX + view.btnW + pad) {
            resumeMatch();
        } else if (x >= view.noX - pad && x <= view.noX + view.btnW + pad) {
            MatchPersistence.clearState();
            newMatch();
        }
        return true;
    }

    function resumeMatch() {
        var state  = MatchPersistence.loadState();
        // State is a flat String-keyed dictionary (see TennisMatchEngine.getState())
        var config = {
            :matchFormat           => state.hasKey("matchFormat") ? state["matchFormat"] : 0,
            :setsToWin             => state["setsToWin"],
            :tiebreakEnabled       => state["tbEnabled"],
            :superTiebreakFinalSet => state["superTBFinal"]
        };
        var engine  = new TennisMatchEngine(config);
        engine.restore(state);

        var manager = new TennisActivityManager();
        manager.startSession();

        // v1.1.2: MainDelegate now takes the MainView by reference.
        var mainView = new MainView(engine, manager);
        Ui.switchToView(
            mainView,
            new MainDelegate(mainView, engine, manager),
            Ui.SLIDE_IMMEDIATE
        );
    }

    function newMatch() {
        // v1.1.2: SetupDelegate now takes the SetupView by reference.
        var setupView = new SetupView();
        Ui.switchToView(
            setupView,
            new SetupDelegate(setupView),
            Ui.SLIDE_IMMEDIATE
        );
    }
}
