// ============================================================
// MainView.mc — Main Match Screen (Touch Zone + Color Feedback)
// Garmin Tennis Tracker for Vivoactive 6
// ============================================================
// This is the screen shown during the match.
//
// TOUCH ZONES (what the player taps during play):
//   ┌─────────────────────┐
//   │  SCORE / TIMER      │  ← top ~40% — display only
//   ├─────────────────────┤
//   │       WON           │  ← middle zone — tap = you won
//   ├──────────┬──────────┤
//   │  ERROR   │    DF    │  ← bottom split — left=error, right=double fault
//   └──────────┴──────────┘
//
// LONG PRESS = UNDO last point
//
// COLOR FEEDBACK (flashes on tap):
//   WON → green flash
//   ERROR → red flash
//   DOUBLE FAULT → orange flash
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Timer as Timer;

// ── MainView — draws the match screen ───────────────────────
class MainView extends Ui.View {

    var engine;             // Reference to TennisMatchEngine
    var feedbackColor;      // Color to flash on the screen after input
    var feedbackTimer;      // Timer that clears the color flash

    function initialize(eng) {
        View.initialize();
        engine        = eng;
        feedbackColor = null;
        feedbackTimer = null;
    }

    function onLayout(dc) {
        // All drawing is done manually in onUpdate.
    }

    // ─────────────────────────────────────────────────────────
    // onUpdate — redraws the full screen every frame
    // ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // ── Background (or color flash) ───────────────────────
        if (feedbackColor != null) {
            dc.setColor(feedbackColor, feedbackColor);
        } else {
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        }
        dc.fillRectangle(0, 0, w, h);

        // ── If match is over, show result instead ─────────────
        if (engine.matchOver) {
            drawMatchOver(dc, w, h);
            return;
        }

        // ── Score display (top section) ───────────────────────
        drawScore(dc, w, h);

        // ── Touch zone labels (bottom section) ───────────────
        drawZoneLabels(dc, w, h);
    }

    // ── drawScore — shows current points, games, sets, timer ─
    function drawScore(dc, w, h) {
        var topH = (h * 42 / 100); // Top 42% of screen

        // Set scores — large, centered
        var playerSets   = engine.player[:sets].toString();
        var opponentSets = engine.opponent[:sets].toString();
        var setsText     = playerSets + " - " + opponentSets;

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 8, Gfx.FONT_NUMBER_MILD, setsText, Gfx.TEXT_JUSTIFY_CENTER);

        // Game scores
        var playerGames   = engine.player[:games].toString();
        var opponentGames = engine.opponent[:games].toString();
        var gamesText     = playerGames + " - " + opponentGames;

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 50, Gfx.FONT_SMALL, gamesText, Gfx.TEXT_JUSTIFY_CENTER);

        // Point scores (using getPointDisplay for deuce/ad labels)
        var playerPts   = engine.getPointDisplay(engine.player);
        var opponentPts = engine.getPointDisplay(engine.opponent);

        // Tiebreak label
        if (engine.inTiebreak) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, 72, Gfx.FONT_XTINY, "TIEBREAK", Gfx.TEXT_JUSTIFY_CENTER);
        } else if (engine.inSuperTiebreak) {
            dc.setColor(Gfx.COLOR_ORANGE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, 72, Gfx.FONT_XTINY, "SUPER TB", Gfx.TEXT_JUSTIFY_CENTER);
        }

        // Current points — large font
        var ptsText = playerPts + "  " + opponentPts;
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 88, Gfx.FONT_NUMBER_HOT, ptsText, Gfx.TEXT_JUSTIFY_CENTER);

        // YOU / OPP labels under points
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2 - 30, 130, Gfx.FONT_XTINY, "YOU", Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2 + 30, 130, Gfx.FONT_XTINY, "OPP", Gfx.TEXT_JUSTIFY_CENTER);

        // Elapsed time — bottom of score area
        var elapsed = engine.getElapsedSeconds();
        var mins    = elapsed / 60;
        var secs    = elapsed % 60;
        var timeStr = mins.format("%02d") + ":" + secs.format("%02d");
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, topH - 16, Gfx.FONT_XTINY, timeStr, Gfx.TEXT_JUSTIFY_CENTER);
    }

    // ── drawZoneLabels — draws WON / ERROR / DF zone hints ───
    function drawZoneLabels(dc, w, h) {
        var topH  = (h * 42 / 100);
        var midH  = (h * 70 / 100);

        // Divider line between score area and touch zones
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(0, topH, w, topH);

        // WON zone (middle band)
        dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, topH + (midH - topH) / 2 - 12, Gfx.FONT_SMALL, "WON", Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, topH + (midH - topH) / 2 + 8, Gfx.FONT_XTINY, "tap", Gfx.TEXT_JUSTIFY_CENTER);

        // Divider line between WON and ERROR/DF zones
        dc.drawLine(0, midH, w, midH);
        // Vertical divider between ERROR and DF zones
        dc.drawLine(w / 2, midH, w / 2, h);

        // ERROR zone (bottom left)
        dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 4, midH + (h - midH) / 2 - 12, Gfx.FONT_TINY, "ERROR", Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 4, midH + (h - midH) / 2 + 6, Gfx.FONT_XTINY, "tap", Gfx.TEXT_JUSTIFY_CENTER);

        // DOUBLE FAULT zone (bottom right)
        dc.setColor(Gfx.COLOR_ORANGE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(3 * w / 4, midH + (h - midH) / 2 - 12, Gfx.FONT_TINY, "D. FAULT", Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(3 * w / 4, midH + (h - midH) / 2 + 6, Gfx.FONT_XTINY, "tap", Gfx.TEXT_JUSTIFY_CENTER);

        // UNDO hint — always visible at very bottom right
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w - 6, h - 14, Gfx.FONT_XTINY, "hold=undo", Gfx.TEXT_JUSTIFY_RIGHT);
    }

    // ── drawMatchOver — shown when the match is finished ─────
    function drawMatchOver(dc, w, h) {
        var playerWon = engine.player[:sets] >= engine.setsToWin;

        dc.setColor(playerWon ? Gfx.COLOR_DK_GREEN : Gfx.COLOR_DK_RED, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 30, Gfx.FONT_LARGE,
            playerWon ? "YOU WIN!" : "MATCH OVER",
            Gfx.TEXT_JUSTIFY_CENTER);

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        var setsText = engine.player[:sets].toString() + "-" + engine.opponent[:sets].toString();
        dc.drawText(w / 2, h / 2 + 5, Gfx.FONT_SMALL, setsText + " sets", Gfx.TEXT_JUSTIFY_CENTER);

        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h - 18, Gfx.FONT_XTINY, "Tap for summary", Gfx.TEXT_JUSTIFY_CENTER);
    }

    // ─────────────────────────────────────────────────────────
    // showFeedback(color)
    // Called by MainDelegate to flash the screen briefly.
    // The timer clears it after 200ms.
    // ─────────────────────────────────────────────────────────
    function showFeedback(color) {
        feedbackColor = color;
        Ui.requestUpdate();

        if (feedbackTimer != null) {
            feedbackTimer.stop();
        }
        feedbackTimer = new Timer.Timer();
        feedbackTimer.start(method(:clearFeedback), 200, false);
    }

    function clearFeedback() {
        feedbackColor = null;
        Ui.requestUpdate();
    }

    function onShow()  {}
    function onHide()  {}
}

// ── MainDelegate — handles all touch input on the match screen
class MainDelegate extends Ui.InputDelegate {

    var engine;

    function initialize(eng) {
        InputDelegate.initialize();
        engine = eng;
    }

    // ─────────────────────────────────────────────────────────
    // onTap — routes tap to the correct input type
    // based on where the user touched the screen.
    // ─────────────────────────────────────────────────────────
    function onTap(clickEvent) {
        var coords = clickEvent.getCoordinates();
        var x      = coords[0];
        var y      = coords[1];

        var view = Ui.getCurrentView()[0];

        // If match is over, tapping goes to PostMatchView
        if (engine.matchOver) {
            goToPostMatch();
            return true;
        }

        // Get screen dimensions (approximate for Vivoactive 6)
        var w   = 390; // approximate — replace with dc.getWidth() if available
        var h   = 450;
        var topH = (h * 42 / 100);
        var midH = (h * 70 / 100);

        if (y < topH) {
            // Tapped score area — do nothing
            return true;
        } else if (y < midH) {
            // WON zone
            engine.handleInput(TennisMatchEngine.WON);
            view.showFeedback(Gfx.COLOR_DK_GREEN);
        } else if (x < w / 2) {
            // ERROR zone (bottom left)
            engine.handleInput(TennisMatchEngine.ERROR);
            view.showFeedback(Gfx.COLOR_RED);
        } else {
            // DOUBLE FAULT zone (bottom right)
            engine.handleInput(TennisMatchEngine.DOUBLE_FAULT);
            view.showFeedback(Gfx.COLOR_ORANGE);
        }

        Ui.requestUpdate();
        return true;
    }

    // ─────────────────────────────────────────────────────────
    // onHold — long press triggers UNDO
    // ─────────────────────────────────────────────────────────
    function onHold(clickEvent) {
        engine.undo();
        var view = Ui.getCurrentView()[0];
        view.showFeedback(Gfx.COLOR_BLUE);
        Ui.requestUpdate();
        return true;
    }

    // Navigate to the post-match summary screen.
    function goToPostMatch() {
        Ui.pushView(
            new PostMatchView(engine),
            new PostMatchDelegate(engine),
            Ui.SLIDE_LEFT
        );
    }
}
