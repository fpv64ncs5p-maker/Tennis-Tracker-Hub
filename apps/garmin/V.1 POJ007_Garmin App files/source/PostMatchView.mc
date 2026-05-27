// ============================================================
// PostMatchView.mc — Post-Match Summary Screen
// Garmin Tennis Tracker for Vivoactive 6
// ============================================================
// Shown automatically when the match ends.
// Displays:
//   - Final set score
//   - Total games and points won
//   - Winners / Unforced Errors / Double Faults
//   - Match duration
//   - Average/max heart rate (if health tracking active)
//   - Steps taken
//
// User can scroll through stats and exit with BACK button.
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Activity as Activity;

// ── PostMatchView — draws the summary screen ─────────────────
class PostMatchView extends Ui.View {

    var engine;         // Reference to TennisMatchEngine (read-only at this point)
    var scrollOffset;   // How far the user has scrolled down
    var pageCount;      // Total number of stat pages

    function initialize(eng) {
        View.initialize();
        engine       = eng;
        scrollOffset = 0;
        pageCount    = 2; // Page 1: score stats | Page 2: health stats
    }

    function onLayout(dc) {}

    // ─────────────────────────────────────────────────────────
    // onUpdate — redraws the summary
    // ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // Background
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, h);

        if (scrollOffset == 0) {
            drawScorePage(dc, w, h);
        } else {
            drawHealthPage(dc, w, h);
        }

        // Page indicator dots at bottom
        drawPageIndicator(dc, w, h);
    }

    // ── Page 1: Score / Match Stats ───────────────────────────
    function drawScorePage(dc, w, h) {
        // Title
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 8, Gfx.FONT_SMALL, "MATCH SUMMARY", Gfx.TEXT_JUSTIFY_CENTER);

        // Result headline
        var playerWon = engine.player[:sets] >= engine.setsToWin;
        dc.setColor(playerWon ? Gfx.COLOR_GREEN : Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 32, Gfx.FONT_SMALL,
            playerWon ? "YOU WON!" : "OPPONENT WON",
            Gfx.TEXT_JUSTIFY_CENTER);

        // Sets
        var setsText = engine.player[:sets].toString() + "-" + engine.opponent[:sets].toString();
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 54, Gfx.FONT_NUMBER_MILD, setsText, Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 94, Gfx.FONT_XTINY, "SETS", Gfx.TEXT_JUSTIFY_CENTER);

        // Stats table
        var y = 115;
        drawStatRow(dc, w, y,      "Winners",       engine.player[:winners].toString(),       engine.opponent[:winners].toString());
        drawStatRow(dc, w, y + 26, "Errors",        engine.player[:unforcedErrors].toString(), engine.opponent[:unforcedErrors].toString());
        drawStatRow(dc, w, y + 52, "Double Faults", engine.player[:doubleFaults].toString(),  engine.opponent[:doubleFaults].toString());

        // Duration
        var elapsed = engine.getElapsedSeconds();
        var mins    = elapsed / 60;
        var secs    = elapsed % 60;
        var durStr  = mins.format("%d") + "m " + secs.format("%02d") + "s";

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y + 82, Gfx.FONT_XTINY, "Duration: " + durStr, Gfx.TEXT_JUSTIFY_CENTER);
    }

    // Helper: draws one row of YOU vs OPP stat
    function drawStatRow(dc, w, y, label, playerVal, oppVal) {
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, Gfx.FONT_XTINY, label, Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 4, y, Gfx.FONT_TINY, playerVal, Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(3 * w / 4, y, Gfx.FONT_TINY, oppVal, Gfx.TEXT_JUSTIFY_CENTER);
    }

    // ── Page 2: Health / Sensor Stats ─────────────────────────
    function drawHealthPage(dc, w, h) {
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 8, Gfx.FONT_SMALL, "HEALTH", Gfx.TEXT_JUSTIFY_CENTER);

        var info = Activity.getActivityInfo();
        var y    = 45;

        // Heart rate
        if (info != null && info has :averageHeartRate && info.averageHeartRate != null) {
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Gfx.FONT_TINY, "♥ HR", Gfx.TEXT_JUSTIFY_CENTER);
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y + 18, Gfx.FONT_SMALL,
                info.averageHeartRate.toString() + " avg / " +
                (info has :maxHeartRate && info.maxHeartRate != null ? info.maxHeartRate.toString() : "--") + " max bpm",
                Gfx.TEXT_JUSTIFY_CENTER);
            y += 52;
        } else {
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Gfx.FONT_TINY, "HR: not available", Gfx.TEXT_JUSTIFY_CENTER);
            y += 30;
        }

        // Steps
        if (info != null && info has :steps && info.steps != null) {
            dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Gfx.FONT_TINY, "Steps", Gfx.TEXT_JUSTIFY_CENTER);
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y + 18, Gfx.FONT_SMALL, info.steps.toString(), Gfx.TEXT_JUSTIFY_CENTER);
            y += 52;
        }

        // Calories (if available)
        if (info != null && info has :calories && info.calories != null) {
            dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Gfx.FONT_TINY, "Calories", Gfx.TEXT_JUSTIFY_CENTER);
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y + 18, Gfx.FONT_SMALL, info.calories.toString() + " kcal", Gfx.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Page indicator dots ───────────────────────────────────
    function drawPageIndicator(dc, w, h) {
        var dotR  = 3;
        var gap   = 10;
        var total = pageCount * gap;
        var startX = (w - total) / 2;

        for (var i = 0; i < pageCount; i++) {
            var cx = startX + i * gap;
            if (i == scrollOffset) {
                dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
                dc.fillCircle(cx, h - 10, dotR);
            } else {
                dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
                dc.fillCircle(cx, h - 10, dotR);
            }
        }
    }

    function onShow() {}
    function onHide() {}
}

// ── PostMatchDelegate — handles navigation in summary ────────
class PostMatchDelegate extends Ui.InputDelegate {

    var engine;

    function initialize(eng) {
        InputDelegate.initialize();
        engine = eng;
    }

    // Swipe left/right to change page.
    function onSwipe(swipeEvent) {
        var dir  = swipeEvent.getDirection();
        var view = Ui.getCurrentView()[0];

        if (dir == Ui.SWIPE_LEFT && view.scrollOffset < view.pageCount - 1) {
            view.scrollOffset += 1;
            Ui.requestUpdate();
        } else if (dir == Ui.SWIPE_RIGHT && view.scrollOffset > 0) {
            view.scrollOffset -= 1;
            Ui.requestUpdate();
        }
        return true;
    }

    // BACK button (or swipe right on first page) exits the app.
    function onBack() {
        // Clear saved match data since match is done
        MatchPersistence.clearState();
        Sys.exit();
        return true;
    }
}
