// ============================================================
// MainView.mc — Main Match Screen (responsive layout)
// MatchMind Tennis Tracker for Garmin Vivoactive 6
// ============================================================
// v1.4.9: NEUTRAL DEAD-ZONE added between the WON area and the ERROR/D.FAULT
// buttons. Fixes ERROR taps silently scoring for YOU when the finger drifts a
// little high: a tap in [deadZoneTopY, buttonTopY) now does nothing (grey
// blink) instead of registering a point. Buttons also made taller, the score
// block nudged up to clear the dead-zone, and the UNDO bar slimmed.
// v1.3.6: earlyUpload() called in MainDelegate.onTap() the instant the last
// point is scored (prevMatchOver false → engine.matchOver true). This fires
// the Supabase POST before any button interaction, so it survives even if the
// OS intercepts the physical button and kills the app.
// v1.2.3: Match end routes through MatchMenu (Save/Discard) instead of
// auto-navigating to PostMatch. Session is no longer stopped at match end
// (avoids activity overlay blocking input). Hint text updated.
// v1.1.2: All y-coordinates are now derived from dc.getHeight()
// percentages. Button hit zones are stored in the view so the
// delegate doesn't need to hardcode pixel ranges. Delegate
// receives the view by reference (no more crashing
// Ui.getCurrentView()[0] casts).
//
// Layout regions (proportional to screen height H):
//   0       Status bar  ── HR, clock, match timer
//   ~22%H   Score area  ── YOU / GAMES / OPP with big points + serve dot
//   ~66%H   Buttons     ── ERROR / D.FAULT
//   ~88%H   Branding    ── "MatchMind"
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Activity as Act;
using Toybox.System as Sys;

class MainView extends Ui.View {

    var engine;
    var feedbackColor;

    // ── Hit-zone bounds, computed each frame, read by delegate ──
    var buttonTopY;        // top of ERROR/D.FAULT buttons
    var buttonBottomY;     // bottom of buttons
    var centerX;           // vertical divider X (also splits the buttons)
    var deadZoneTopY;      // v1.4.9: WON ends here; [deadZoneTopY, buttonTopY) is a neutral buffer

    function initialize(eng, mgr) {
        View.initialize();
        engine        = eng;
        feedbackColor = null;
        buttonTopY    = 0;
        buttonBottomY = 0;
        centerX       = 0;
        deadZoneTopY  = 0;
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // ── Color flash feedback (one frame only) ─────────────
        if (feedbackColor != null) {
            dc.setColor(feedbackColor, feedbackColor);
            dc.fillRectangle(0, 0, w, h);
            feedbackColor = null;
            Ui.requestUpdate();
            return;
        }

        // ── Black background ──────────────────────────────────
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, h);

        // ── Match over — show result screen ───────────────────
        if (engine.matchOver) {
            drawMatchOver(dc, w, h);
            return;
        }

        // ── Compute responsive anchor points ──────────────────
        // v1.1.4: HR/clock and timer pushed down so the round bezel
        // doesn't clip them. Buttons taller for easier finger taps.
        centerX           = w / 2;
        var statusDivY    = h * 23 / 100;
        // v1.4.9: neutral dead-zone sits between the WON area and the scoring
        // buttons. A tap in [deadZoneTopY, buttonTopY) does nothing instead of
        // being misread as a point for YOU. Buttons start higher and run lower
        // (UNDO slimmed) so ERROR/D.FAULT are a bigger target.
        deadZoneTopY      = h * 58 / 100;
        buttonTopY        = h * 63 / 100;
        buttonBottomY     = h * 87 / 100;

        drawStatusBar(dc, w, h, statusDivY);
        drawScoreArea(dc, w, h, statusDivY, buttonTopY);
        drawButtons(dc, w, h, buttonTopY, buttonBottomY);
        drawUndoButton(dc, w, h, buttonBottomY);
    }

    // ─────────────────────────────────────────────────────────
    // drawStatusBar — HR, clock, match timer
    // ─────────────────────────────────────────────────────────
    function drawStatusBar(dc, w, h, divY) {
        // v1.1.4: pushed both rows further down so the round bezel
        // doesn't clip the edges of the HR/clock text on a real watch.
        var line1Y = h * 8 / 100;
        var line2Y = h * 17 / 100;

        // Heart rate
        var hrStr = "--";
        var actInfo = Act.getActivityInfo();
        if (actInfo != null && actInfo.currentHeartRate != null) {
            hrStr = actInfo.currentHeartRate.toString();
        }

        // Clock
        var ct = Sys.getClockTime();
        var clockStr = ct.hour.format("%d") + ":" + ct.min.format("%02d");

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(centerX - 8, line1Y, Gfx.FONT_XTINY, "HR:" + hrStr,
            Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(centerX + 8, line1Y, Gfx.FONT_XTINY, clockStr,
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);

        // Match timer
        var elapsed = engine.getElapsedSeconds();
        var hrs     = elapsed / 3600;
        var mins    = (elapsed % 3600) / 60;
        var secs    = elapsed % 60;
        var timerStr;
        if (hrs > 0) {
            timerStr = hrs.format("%d") + ":" + mins.format("%02d") + ":" + secs.format("%02d");
        } else {
            timerStr = mins.format("%02d") + ":" + secs.format("%02d");
        }
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(centerX, line2Y, Gfx.FONT_XTINY, timerStr,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // v1.1.4: change-over indicator. Shown after odd games of the set,
        // and every 6 points during a tiebreak. Cleared automatically when
        // the next point is scored.
        if (engine.needsChangeover) {
            var changeoverY = (line2Y + divY) / 2;
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(centerX, changeoverY, Gfx.FONT_XTINY,
                "* SWITCH ENDS *",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        } else {
            // Divider line (only shown when no changeover banner)
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(20, divY, w - 20, divY);
        }
    }

    // ─────────────────────────────────────────────────────────
    // drawScoreArea — P1 left, set history centre, P2 right
    // ─────────────────────────────────────────────────────────
    function drawScoreArea(dc, w, h, statusDivY, buttonTopY) {
        // Anchor positions inside the score band
        var p1x         = w * 23 / 100;       // P1 column centre
        var p2x         = w * 77 / 100;       // P2 column centre
        var labelsY     = statusDivY + (h * 3 / 100);   // v1.4.9: raised ~2% to clear the dead-zone
        var gamesY      = labelsY + (h * 7 / 100);      // ~115
        var histTopY    = labelsY + (h * 21 / 100);     // ~170 — set history rows
        var pointsY     = labelsY + (h * 22 / 100);     // big points text top
        var ovalCY      = labelsY + (h * 24 / 100);     // v1.4.9: raised so the oval sits fully above the dead-zone

        // ── Player labels ─────────────────────────────────────
        // v1.1.2: renamed P1/P2 → YOU/OPP for at-a-glance clarity.
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(p1x, labelsY, Gfx.FONT_TINY, "YOU",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(p1x - 18, labelsY + 12, p1x + 18, labelsY + 12);

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(p2x, labelsY, Gfx.FONT_TINY, "OPP",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // ── Server indicator: tennis-ball-yellow dot above whoever serves
        // Engine.playerServing flips automatically between games and inside
        // tiebreaks, so this stays correct without extra logic.
        var ballR = 6;
        var ballY = labelsY - 16;
        dc.setColor(0xC8E63C, Gfx.COLOR_TRANSPARENT);  // matches launcher icon
        if (engine.playerServing) {
            dc.fillCircle(p1x, ballY, ballR);
        } else {
            dc.fillCircle(p2x, ballY, ballR);
        }

        // ── Centre: tiebreak indicator OR games row ──────────
        if (engine.inTiebreak) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(centerX, labelsY, Gfx.FONT_XTINY, "TIEBREAK",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        } else if (engine.inSuperTiebreak) {
            dc.setColor(Gfx.COLOR_ORANGE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(centerX, labelsY, Gfx.FONT_XTINY, "SUPER TB",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(0x444444, Gfx.COLOR_TRANSPARENT);
            dc.drawText(centerX, labelsY, Gfx.FONT_XTINY, "GAMES",
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            var gamesStr = engine.player[:games].toString() + "-" + engine.opponent[:games].toString();
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(centerX, gamesY, Gfx.FONT_SMALL, gamesStr,
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }

        // ── Set history ───────────────────────────────────────
        var sh = engine.setHistory;
        if (sh != null && sh.size() > 0) {
            dc.setColor(0x333333, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(centerX - 18, histTopY - 8, centerX + 18, histTopY - 8);
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            for (var i = 0; i < sh.size() && i < 3; i++) {
                var entry  = sh[i];
                var setStr = entry[:p].toString() + "-" + entry[:o].toString();
                dc.drawText(centerX, histTopY + (i * 18), Gfx.FONT_XTINY, setStr,
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            }
        }

        // ── Green oval behind P1 points ───────────────────────
        var ovalRX = w * 12 / 100;
        var ovalRY = h * 8 / 100;   // v1.4.9: slightly smaller so it clears the dead-zone
        dc.setColor(0x003300, Gfx.COLOR_TRANSPARENT);
        dc.fillEllipse(p1x, ovalCY, ovalRX, ovalRY);

        // ── Current points — large font ───────────────────────
        var p1Pts = engine.getPointDisplay(engine.player);
        var p2Pts = engine.getPointDisplay(engine.opponent);

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(p1x, ovalCY, Gfx.FONT_NUMBER_MILD, p1Pts,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(p2x, ovalCY, Gfx.FONT_NUMBER_MILD, p2Pts,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // ── Centre vertical divider ───────────────────────────
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(centerX, labelsY, centerX, buttonTopY - 2);
    }

    // ─────────────────────────────────────────────────────────
    // drawButtons — ERROR and D.FAULT
    // Inset from edges to stay visible on round screen.
    // ─────────────────────────────────────────────────────────
    function drawButtons(dc, w, h, btnTopY, btnBotY) {
        // v1.1.4: visual rectangles now fill the full tap zone (was inset
        // 4px making them look smaller than they actually were). Inset
        // pulled in slightly for narrower, taller buttons. Label font
        // bumped from XTINY to TINY for readability mid-rally.
        var btnH    = btnBotY - btnTopY;
        var inset   = w * 16 / 100;
        var gap     = w * 2 / 100;

        // Divider above buttons
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(40, btnTopY - 1, w - 40, btnTopY - 1);

        // Left button (ERROR) — visual matches the tap zone exactly
        var lBtnX = inset;
        var lBtnW = centerX - inset - gap;
        dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(lBtnX, btnTopY, lBtnW, btnH);

        // Right button (D.FAULT)
        var rBtnX = centerX + gap;
        var rBtnW = w - centerX - gap - inset;
        dc.drawRectangle(rBtnX, btnTopY, rBtnW, btnH);

        // Labels — vertically centred, bigger font
        var lblY = btnTopY + btnH / 2;
        dc.drawText(lBtnX + lBtnW / 2, lblY, Gfx.FONT_TINY, "ERROR",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(rBtnX + rBtnW / 2, lblY, Gfx.FONT_TINY, "D.FAULT",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // ─────────────────────────────────────────────────────────
    // drawUndoButton — v1.4.8: dedicated UNDO control (replaces the
    // "MatchMind" branding). The swipe-up undo proved unreliable on
    // the real watch: fast swipes register as taps on the top half,
    // ADDING a point for the player instead of undoing one. The tap
    // zone is the full strip below the ERROR/D.FAULT buttons.
    // ─────────────────────────────────────────────────────────
    function drawUndoButton(dc, w, h, btnBotY) {
        // v1.4.9: slim UNDO bar. The tap target is the whole strip below the
        // buttons (see MainDelegate), so this is just an affordance — kept
        // short and narrow enough to stay inside the round bezel, freeing
        // vertical space for the taller ERROR/D.FAULT buttons above.
        var btnW = w * 32 / 100;
        var btnX = w / 2 - btnW / 2;
        var btnY = btnBotY + 3;
        var btnH = h * 7 / 100;
        if (btnH < 16) { btnH = 16; }

        dc.setColor(Gfx.COLOR_DK_BLUE, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(btnX, btnY, btnW, btnH);
        dc.setColor(Gfx.COLOR_BLUE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, btnY + btnH / 2, Gfx.FONT_XTINY, "UNDO",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    function drawMatchOver(dc, w, h) {
        var playerWon = engine.player[:sets] >= engine.setsToWin;

        dc.setColor(playerWon ? Gfx.COLOR_DK_GREEN : Gfx.COLOR_DK_RED, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 40 / 100, Gfx.FONT_LARGE,
            playerWon ? "YOU WIN!" : "MATCH OVER",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        var setsText = engine.player[:sets].toString() + "-" + engine.opponent[:sets].toString();
        dc.drawText(w / 2, h * 55 / 100, Gfx.FONT_SMALL, setsText + " sets",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 90 / 100, Gfx.FONT_XTINY, "Tap to save or discard",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    function showFeedback(color) {
        feedbackColor = color;
        Ui.requestUpdate();
    }

    function onShow() {}
    function onHide() {}
}

// ── MainDelegate — handles all touch input on the match screen ──
// v1.1.2: receives MainView by reference. Reads buttonTopY / centerX
// from view to figure out tap zones.
class MainDelegate extends Ui.InputDelegate {

    var view;
    var engine;
    var manager;

    function initialize(mainView, eng, mgr) {
        InputDelegate.initialize();
        view    = mainView;
        engine  = eng;
        manager = mgr;
    }

    function onTap(clickEvent) {
        if (view == null || engine == null) { return true; }

        var coords = clickEvent.getCoordinates();
        var x      = coords[0];
        var y      = coords[1];

        if (engine.matchOver) {
            showConfirm();
            return true;
        }

        // Use the layout values the view computed last frame.
        // Fallback to safe defaults if onUpdate hasn't run yet.
        var btnTop  = (view.buttonTopY > 0)    ? view.buttonTopY    : 246;
        var btnBot  = (view.buttonBottomY > 0) ? view.buttonBottomY : 339;
        var cx      = (view.centerX > 0)       ? view.centerX       : 195;
        var deadTop = (view.deadZoneTopY > 0)  ? view.deadZoneTopY  : 226;

        // v1.4.8: UNDO — the full strip below the ERROR/D.FAULT buttons.
        // Handled BEFORE the scoring zones so an undo can never be
        // misread as a point input.
        if (y > btnBot) {
            engine.undo();
            MatchPersistence.saveState(engine);
            view.showFeedback(Gfx.COLOR_DK_BLUE);
            Ui.requestUpdate();
            return true;
        }

        // v1.4.9: NEUTRAL DEAD-ZONE between the WON area (top) and the
        // ERROR/D.FAULT buttons. A tap here does NOTHING (grey blink) instead
        // of being misread as a point for YOU — the fix for ERROR taps that
        // silently scored for the player when the finger drifted a bit high.
        if (y >= deadTop && y < btnTop) {
            view.showFeedback(Gfx.COLOR_DK_GRAY);
            Ui.requestUpdate();
            return true;
        }

        // v1.1.5: snapshot SET total before scoring so we can detect a
        // set-end transition and write a FIT lap with per-set custom
        // fields (Set points won / Errors / D.Faults / Tiebreak result).
        // One lap row per set in Garmin Connect's Laps tab.
        var prevSetsTotal = engine.player[:sets] + engine.opponent[:sets];

        // v1.3.6: snapshot matchOver BEFORE the point is scored so we can
        // detect the exact moment the match ends and fire earlyUpload().
        var prevMatchOver = engine.matchOver;

        if (y < deadTop) {
            engine.handleInput(engine.WON);
            view.showFeedback(Gfx.COLOR_DK_GREEN);
        } else if (x < cx) {
            engine.handleInput(engine.ERROR);
            view.showFeedback(Gfx.COLOR_RED);
        } else {
            engine.handleInput(engine.DOUBLE_FAULT);
            view.showFeedback(Gfx.COLOR_ORANGE);
        }

        // Did a set just complete? If yes, mark a lap with per-set fields.
        var newSetsTotal = engine.player[:sets] + engine.opponent[:sets];
        if (newSetsTotal > prevSetsTotal) {
            if (manager != null) { manager.markSetEnd(engine); }
        }

        // v1.3.6: fire Supabase upload the instant the last point is scored.
        // This runs while the activity session is still live and Bluetooth
        // is still connected — decoupling the POST from whatever happens next
        // (tap, MatchMenu SAVE, or physical button intercepted by the OS).
        if (!prevMatchOver && engine.matchOver) {
            if (manager != null) { manager.earlyUpload(engine); }
        }

        manager.updateMetrics(engine);
        MatchPersistence.saveState(engine);

        Ui.requestUpdate();
        return true;
    }

    function onSwipe(swipeEvent) {
        if (engine == null) { return true; }
        var dir = swipeEvent.getDirection();
        if (dir == Ui.SWIPE_UP) {
            // Undo last point
            engine.undo();
            MatchPersistence.saveState(engine);
            Ui.requestUpdate();
        } else if (dir == Ui.SWIPE_DOWN) {
            // v1.1.3: swipe DOWN opens End Match? dialog. The lower
            // (start/stop) button is often intercepted by the watch's
            // ActivityRecording system on a real device, so swipe is
            // the reliable way to end a match.
            showConfirm();
        }
        return true;  // consume LEFT/RIGHT to prevent system back-nav
    }

    function goToPostMatch() {
        var pmView = new PostMatchView(engine, manager);
        Ui.pushView(
            pmView,
            new PostMatchDelegate(pmView, engine, manager),
            Ui.SLIDE_LEFT
        );
    }

    // v1.1.3: BACK button now leaves the app cleanly. Match state is
    // auto-saved on every point by MatchPersistence, so the user can
    // resume on next launch (Resume match? prompt).
    function onBack() {
        // If the match is over, BACK should go to the summary (not silently exit
        // and skip MatchHistory.saveMatch). Tapping and pressing BACK now both
        // reach PostMatchDelegate.finishAndExit() which saves history correctly.
        if (engine != null && engine.matchOver) {
            showConfirm();
            return true;
        }
        Ui.popView(Ui.SLIDE_RIGHT);     // Main → Setup (or → exit if root)
        Ui.popView(Ui.SLIDE_IMMEDIATE); // Setup → exit (no-op if already exited)
        return true;
    }

    // Lower (start/stop) button — also opens End Match? dialog if the
    // watch lets us catch it. On real Vivoactive 6 the system tends to
    // intercept this for ActivityRecording pause; swipe DOWN is the
    // reliable alternative.
    function onKey(keyEvent) {
        showConfirm();
        return true;
    }

    // Always show the MatchMenu — for both mid-game and match-over.
    // At match end: RESUME returns to result screen, SAVE → PostMatch → history saved,
    // DISCARD → confirmation. This gives a consistent save/discard UX and avoids
    // stopping the activity session early (which triggers the blue triangle overlay).
    function showConfirm() {
        if (engine == null) { return; }
        var menuView = new MatchMenuView();
        Ui.pushView(
            menuView,
            new MatchMenuDelegate(menuView, engine, manager),
            Ui.SLIDE_UP
        );
    }
}

// ── ConfirmEndView — "End Match?" screen ─────────────────────
// v1.1.2: button positions stored on the view; delegate reads them.
class ConfirmEndView extends Ui.View {

    var yesY;
    var yesH;
    var noY;
    var noH;

    function initialize() {
        View.initialize();
        yesY = 0;
        yesH = 0;
        noY  = 0;
        noH  = 0;
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, h);

        // v1.1.2: more vertical breathing room between hint text and the
        // next button — they were crowded together on the real watch.
        var titleY    = h * 19 / 100;
        var dividerY  = titleY + dc.getFontHeight(Gfx.FONT_SMALL) + 4;
        yesY          = h * 33 / 100;
        yesH          = h * 12 / 100;
        var yesHintY  = yesY + yesH + 8;
        noY           = h * 60 / 100;
        noH           = h * 12 / 100;
        var noHintY   = noY + noH + 8;

        var btnW  = w * 32 / 100;
        var btnX  = w / 2 - btnW / 2;

        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, titleY, Gfx.FONT_SMALL, "END MATCH?",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        dc.setColor(0x333333, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(w / 2 - 70, dividerY, w / 2 + 70, dividerY);

        // YES — green filled
        dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_DK_GREEN);
        dc.fillRoundedRectangle(btnX, yesY, btnW, yesH, 8);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, yesY + yesH / 2, Gfx.FONT_SMALL, "YES",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, yesHintY, Gfx.FONT_XTINY, "see match stats",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // NO — red outline
        dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(btnX, noY, btnW, noH);
        dc.drawText(w / 2, noY + noH / 2, Gfx.FONT_SMALL, "NO",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, noHintY, Gfx.FONT_XTINY, "back to match",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    function onShow() {}
    function onHide() {}
}

// ── ConfirmEndDelegate — YES / NO / both buttons = NO ────────
// v1.1.2: receives ConfirmEndView by reference. Reads button
// bounds directly (no Ui.getCurrentView() / instanceof — that
// pattern didn't reliably resolve on the real watch).
class ConfirmEndDelegate extends Ui.InputDelegate {

    var view;
    var engine;
    var manager;

    function initialize(confirmView, eng, mgr) {
        InputDelegate.initialize();
        view    = confirmView;
        engine  = eng;
        manager = mgr;
    }

    function onTap(clickEvent) {
        if (view == null) { return true; }

        var y = clickEvent.getCoordinates()[1];
        var pad = 10;  // generous finger-tap padding

        // YES button
        if (view.yesH > 0 && y >= view.yesY - pad && y <= view.yesY + view.yesH + pad) {
            var pmView = new PostMatchView(engine, manager);
            Ui.pushView(
                pmView,
                new PostMatchDelegate(pmView, engine, manager),
                Ui.SLIDE_LEFT
            );
            return true;
        }

        // NO button
        if (view.noH > 0 && y >= view.noY - pad && y <= view.noY + view.noH + pad) {
            Ui.popView(Ui.SLIDE_DOWN);
            return true;
        }

        return true;
    }

    function onBack() {
        Ui.popView(Ui.SLIDE_DOWN);
        return true;
    }

    function onKey(keyEvent) {
        Ui.popView(Ui.SLIDE_DOWN);
        return true;
    }
}
