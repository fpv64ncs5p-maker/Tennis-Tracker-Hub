// ============================================================
// PostMatchView.mc — Post-Match Summary Screen
// MatchMind Tennis Tracker for Vivoactive 6
// ============================================================
// v1.1.2: Responsive layout. Delegate receives view by reference.
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Activity as Activity;

class PostMatchView extends Ui.View {

    var engine;
    var scrollOffset;
    var pageCount;

    function initialize(eng, mgr) {
        View.initialize();
        engine       = eng;
        scrollOffset = 0;
        pageCount    = 2;
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, h);

        if (scrollOffset == 0) {
            drawScorePage(dc, w, h);
        } else {
            drawHealthPage(dc, w, h);
        }

        drawPageIndicator(dc, w, h);
    }

    // ── Page 1: Score / Match Stats ───────────────────────────
    function drawScorePage(dc, w, h) {
        // v1.1.2: pushed title + result down so they're not clipped by the
        // round bezel, and shortened result text ("OPP WON" instead of
        // "OPPONENT WON") to fit the narrower visible chord at top.
        // Tightened firstRowY + rowGap so the Duration row doesn't crowd
        // the round bezel at the bottom.
        var titleY     = h * 12 / 100;
        var resultY    = h * 20 / 100;
        var dividerY   = h * 27 / 100;
        var firstRowY  = h * 30 / 100;
        var rowGap     = dc.getFontHeight(Gfx.FONT_XTINY) + 2;

        var lx = w / 2 - (w * 5 / 100);  // label right edge
        var vx = w / 2 + (w * 7 / 100);  // value left edge

        // Title — shorter text, FONT_XTINY
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, titleY, Gfx.FONT_XTINY, "SUMMARY",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // Result — short, fits even at narrow chord
        var playerWon = engine.player[:sets] >= engine.setsToWin;
        dc.setColor(playerWon ? Gfx.COLOR_GREEN : Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, resultY, Gfx.FONT_SMALL,
            playerWon ? "YOU WIN!" : "OPP WON",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // Divider
        dc.setColor(0x333333, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(w / 2 - 60, dividerY, w / 2 + 60, dividerY);

        // First row label/value depend on match format
        var firstLabel;
        var setsText;
        if (engine.matchFormat == 1) {
            firstLabel = "TB Score";
            if (engine.setHistory != null && engine.setHistory.size() > 0) {
                var tb = engine.setHistory[0];
                setsText = tb[:p].toString() + "-" + tb[:o].toString();
            } else {
                setsText = engine.player[:points].toString() + "-" + engine.opponent[:points].toString();
            }
        } else if (engine.matchFormat == 2) {
            firstLabel = "Super TB";
            if (engine.setHistory != null && engine.setHistory.size() > 0) {
                var tb = engine.setHistory[0];
                setsText = tb[:p].toString() + "-" + tb[:o].toString();
            } else {
                setsText = engine.player[:points].toString() + "-" + engine.opponent[:points].toString();
            }
        } else {
            firstLabel = "Sets";
            setsText = engine.player[:sets].toString() + "-" + engine.opponent[:sets].toString();
        }

        var elapsed = engine.getElapsedSeconds();
        var mins    = elapsed / 60;
        var secs    = elapsed % 60;
        var durStr  = mins.format("%d") + "m " + secs.format("%02d") + "s";

        var ptsWon  = engine.player[:winners];
        var ptsLost = engine.player[:unforcedErrors] + engine.player[:doubleFaults];
        var ptsStr  = ptsWon.toString() + " / " + ptsLost.toString();

        var srvStr  = engine.player[:servePtsWon].toString() + "/" + engine.player[:servePtsPlayed].toString();
        var retStr  = engine.player[:returnPtsWon].toString() + "/" + engine.player[:returnPtsPlayed].toString();

        drawInfoRow(dc, lx, vx, firstRowY,               firstLabel, setsText);
        drawInfoRow(dc, lx, vx, firstRowY + rowGap,      "Pts W/L",  ptsStr);
        drawInfoRow(dc, lx, vx, firstRowY + rowGap * 2,  "Srv Pts",  srvStr);
        drawInfoRow(dc, lx, vx, firstRowY + rowGap * 3,  "Ret Pts",  retStr);
        drawInfoRow(dc, lx, vx, firstRowY + rowGap * 4,  "Winners",  engine.player[:winners].toString());
        drawInfoRow(dc, lx, vx, firstRowY + rowGap * 5,  "Errors",   engine.player[:unforcedErrors].toString());
        drawInfoRow(dc, lx, vx, firstRowY + rowGap * 6,  "D.Faults", engine.player[:doubleFaults].toString());
        drawInfoRow(dc, lx, vx, firstRowY + rowGap * 7,  "Duration", durStr);
    }

    function drawInfoRow(dc, lx, vx, y, label, value) {
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(lx, y, Gfx.FONT_XTINY, label,
            Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(vx, y, Gfx.FONT_XTINY, value,
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // ── Page 2: Health / Sensor Stats ─────────────────────────
    function drawHealthPage(dc, w, h) {
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 5 / 100, Gfx.FONT_SMALL, "HEALTH",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        var info = Activity.getActivityInfo();
        var y    = h * 18 / 100;
        var step = h * 14 / 100;

        if (info != null && info has :averageHeartRate && info.averageHeartRate != null) {
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Gfx.FONT_TINY, "HR",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            var maxHr = (info has :maxHeartRate && info.maxHeartRate != null)
                ? info.maxHeartRate.toString() : "--";
            dc.drawText(w / 2, y + 22, Gfx.FONT_SMALL,
                info.averageHeartRate.toString() + " avg / " + maxHr + " max",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            y += step;
        } else {
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Gfx.FONT_TINY, "HR: not available",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            y += step;
        }

        if (info != null && info has :steps && info.steps != null) {
            dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Gfx.FONT_TINY, "Steps",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y + 22, Gfx.FONT_SMALL, info.steps.toString(),
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            y += step;
        }

        if (info != null && info has :calories && info.calories != null) {
            dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Gfx.FONT_TINY, "Calories",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y + 22, Gfx.FONT_SMALL, info.calories.toString() + " kcal",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
    }

    function drawPageIndicator(dc, w, h) {
        var dotR  = 3;
        var gap   = 10;
        var total = pageCount * gap;
        var startX = (w - total) / 2;
        var dotY   = h - (h * 5 / 100);

        for (var i = 0; i < pageCount; i++) {
            var cx = startX + i * gap;
            if (i == scrollOffset) {
                dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            }
            dc.fillCircle(cx, dotY, dotR);
        }
    }

    function onShow() {}
    function onHide() {}
}

// ── PostMatchDelegate ────────────────────────────────────────
// v1.1.2: receives view by reference (when available). The
// ConfirmEnd → PostMatch path passes the view; older callers
// can still pass null safely.
class PostMatchDelegate extends Ui.InputDelegate {

    var view;
    var engine;
    var manager;

    function initialize(pmView, eng, mgr) {
        InputDelegate.initialize();
        view    = pmView;
        engine  = eng;
        manager = mgr;
    }

    function onSwipe(swipeEvent) {
        if (view == null) {
            // Recover the view if we weren't given one
            var v = Ui.getCurrentView();
            if (v instanceof PostMatchView) {
                view = v as PostMatchView;
            }
        }
        if (view == null) { return true; }

        var dir = swipeEvent.getDirection();
        if (dir == Ui.SWIPE_LEFT && view.scrollOffset < view.pageCount - 1) {
            view.scrollOffset += 1;
            Ui.requestUpdate();
        } else if (dir == Ui.SWIPE_RIGHT && view.scrollOffset > 0) {
            view.scrollOffset -= 1;
            Ui.requestUpdate();
        }
        return true;
    }

    function onBack() {
        finishAndExit();
        return true;
    }

    function onKey(keyEvent) {
        finishAndExit();
        return true;
    }

    // v1.1.3: Unwind the view stack instead of pushing yet another SetupView
    // on top. The stack on entry to PostMatchView is:
    //   [SetupView, MainView, ConfirmEndView, PostMatchView]   (fresh match)
    //   [MainView, ConfirmEndView, PostMatchView]              (resumed match)
    // Three popViews unwind it to the original SetupView (or exit the app
    // for the resumed-match path, where the SetupView wasn't kept). From
    // there, pressing back from SetupView exits the app naturally.
    function finishAndExit() {
        // v1.3: save match to local history before clearing state
        MatchHistory.saveMatch(engine);
        if (manager != null) { manager.stopSession(engine); }
        MatchPersistence.clearState();
        Ui.popView(Ui.SLIDE_RIGHT);
        Ui.popView(Ui.SLIDE_IMMEDIATE);
        Ui.popView(Ui.SLIDE_IMMEDIATE);
    }
}
