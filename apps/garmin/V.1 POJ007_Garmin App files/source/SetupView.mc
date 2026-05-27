// ============================================================
// SetupView.mc — Pre-Match Configuration Screen
// Garmin Tennis Tracker for Vivoactive 6
// ============================================================
// This is the first screen the player sees.
// It lets them configure:
//   - Number of sets to win (1 or 2)
//   - Tiebreak on/off
//   - Super tiebreak (match tiebreak) on/off
//
// When the player taps START, it launches MainView.
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;

// ── SetupView — draws the setup screen ──────────────────────
class SetupView extends Ui.View {

    // Current configuration values (defaults)
    var setsToWin;
    var tiebreakEnabled;
    var superTiebreakFinalSet;

    // Which setting is currently selected (for highlight)
    // 0 = sets, 1 = tiebreak, 2 = super tiebreak, 3 = START
    var selectedItem;

    function initialize() {
        View.initialize();
        setsToWin             = 2;    // Best of 3 by default
        tiebreakEnabled       = true;
        superTiebreakFinalSet = true;
        selectedItem          = 0;
    }

    // onLayout is called once to set up the view dimensions.
    function onLayout(dc) {
        // Nothing to load from layout file — we draw everything manually.
    }

    // onUpdate is called every time the screen needs to be redrawn.
    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // ── Background ───────────────────────────────────────
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, h);

        // ── Title ────────────────────────────────────────────
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 10, Gfx.FONT_SMALL, "TENNIS", Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 28, Gfx.FONT_TINY, "SETUP", Gfx.TEXT_JUSTIFY_CENTER);

        // ── Setting rows ─────────────────────────────────────
        // Row 1: Sets to win
        drawRow(dc, w, 60, "SETS", setsToWin == 2 ? "Best of 3" : "Best of 1", selectedItem == 0);

        // Row 2: Tiebreak
        drawRow(dc, w, 100, "TIEBREAK", tiebreakEnabled ? "ON" : "OFF", selectedItem == 1);

        // Row 3: Super tiebreak
        drawRow(dc, w, 140, "SUPER TB", superTiebreakFinalSet ? "ON" : "OFF", selectedItem == 2);

        // ── Start button ─────────────────────────────────────
        var startColor = (selectedItem == 3) ? Gfx.COLOR_GREEN : Gfx.COLOR_DK_GREEN;
        dc.setColor(startColor, startColor);
        dc.fillRoundedRectangle(w / 2 - 45, 175, 90, 32, 8);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 181, Gfx.FONT_SMALL, "START", Gfx.TEXT_JUSTIFY_CENTER);

        // ── Hint ─────────────────────────────────────────────
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h - 18, Gfx.FONT_XTINY, "Tap to toggle  |  Swipe to navigate", Gfx.TEXT_JUSTIFY_CENTER);
    }

    // Helper: draws one settings row with label and value.
    function drawRow(dc, w, y, label, value, isSelected) {
        var bg = isSelected ? Gfx.COLOR_DK_BLUE : Gfx.COLOR_TRANSPARENT;
        if (isSelected) {
            dc.setColor(bg, bg);
            dc.fillRoundedRectangle(8, y - 4, w - 16, 28, 6);
        }
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(16, y, Gfx.FONT_TINY, label, Gfx.TEXT_JUSTIFY_LEFT);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w - 16, y, Gfx.FONT_TINY, value, Gfx.TEXT_JUSTIFY_RIGHT);
    }

    // Called when the view becomes active (shown on screen).
    function onShow() {}

    // Called when the view is hidden (another view pushed on top).
    function onHide() {}
}

// ── SetupDelegate — handles input on the setup screen ───────
class SetupDelegate extends Ui.InputDelegate {

    var view;

    function initialize() {
        InputDelegate.initialize();
    }

    // Called when user taps the screen.
    function onTap(clickEvent) {
        var coords = clickEvent.getCoordinates();
        var x = coords[0];
        var y = coords[1];

        // Use touch coordinates to decide what was tapped.
        // These Y ranges correspond to the rows drawn in SetupView.
        if (y >= 56 && y <= 90) {
            // Tapped "Sets to win" row — toggle between 1 and 2
            toggleSets();
        } else if (y >= 96 && y <= 130) {
            // Tapped "Tiebreak" row
            toggleTiebreak();
        } else if (y >= 136 && y <= 170) {
            // Tapped "Super tiebreak" row
            toggleSuperTiebreak();
        } else if (y >= 172 && y <= 212) {
            // Tapped START button — launch the match
            startMatch();
        }

        Ui.requestUpdate();
        return true;
    }

    // Swipe down moves selection down; swipe up moves it up.
    function onSwipe(swipeEvent) {
        var dir = swipeEvent.getDirection();
        var v   = Ui.getCurrentView()[0];

        if (dir == Ui.SWIPE_DOWN) {
            if (v.selectedItem < 3) { v.selectedItem += 1; }
        } else if (dir == Ui.SWIPE_UP) {
            if (v.selectedItem > 0) { v.selectedItem -= 1; }
        }

        Ui.requestUpdate();
        return true;
    }

    // Toggle sets between 1 and 2 (Best of 1 / Best of 3).
    function toggleSets() {
        var v = Ui.getCurrentView()[0];
        v.setsToWin = (v.setsToWin == 2) ? 1 : 2;
    }

    function toggleTiebreak() {
        var v = Ui.getCurrentView()[0];
        v.tiebreakEnabled = !v.tiebreakEnabled;
    }

    function toggleSuperTiebreak() {
        var v = Ui.getCurrentView()[0];
        v.superTiebreakFinalSet = !v.superTiebreakFinalSet;
    }

    // Build the config and push the MainView.
    function startMatch() {
        var v = Ui.getCurrentView()[0];

        var config = {
            :setsToWin             => v.setsToWin,
            :tiebreakEnabled       => v.tiebreakEnabled,
            :superTiebreakFinalSet => v.superTiebreakFinalSet
        };

        var engine = new TennisMatchEngine(config);

        Ui.pushView(
            new MainView(engine),
            new MainDelegate(engine),
            Ui.SLIDE_LEFT
        );
    }
}
