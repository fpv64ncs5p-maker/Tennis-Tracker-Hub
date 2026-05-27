// ============================================================
// MatchMenu.mc — Mid-Match Action Menu
// MatchMind Tennis Tracker for Vivoactive 6
// ============================================================
// Pushed when the user presses BACK on the match screen (or
// swipes DOWN). Mirrors Garmin's native activity-stop menu —
// vertical list with four options:
//
//   ▶  RESUME   — back to the match
//   ↓  SAVE     — end match, save activity to Garmin Connect
//   ⏰ LATER    — leave app, match auto-saved for resume
//   ✕  DISCARD  — throw match away (with confirmation)
//
// Navigation:
//   • Tap an option directly to select it.
//   • Swipe UP/DOWN to highlight, then BACK to confirm.
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;

class MatchMenuView extends Ui.View {

    var selectedOption;   // 0=Resume 1=Save 2=Later 3=Discard
    var optionYs;         // y-centre for each option box
    var optionH;          // height of each option box

    function initialize() {
        View.initialize();
        selectedOption = 0;
        optionYs       = null;
        optionH        = 0;
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, h);

        // Title
        var titleY = h * 8 / 100;
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, titleY, Gfx.FONT_XTINY, "MATCH MENU",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // Distribute 4 option boxes evenly between titleY and bottom margin
        optionH = h * 14 / 100;
        var listTop    = h * 17 / 100;
        var listBottom = h * 96 / 100;
        var availableH = listBottom - listTop;
        var totalH     = optionH * 4;
        var spacing    = (availableH - totalH) / 3;
        if (spacing < 4) { spacing = 4; }

        optionYs = [
            listTop + optionH / 2,
            listTop + optionH + spacing + optionH / 2,
            listTop + (optionH + spacing) * 2 + optionH / 2,
            listTop + (optionH + spacing) * 3 + optionH / 2
        ];

        var labels = ["RESUME", "SAVE", "LATER", "DISCARD"];
        for (var i = 0; i < 4; i++) {
            drawOption(dc, w, optionYs[i], optionH, labels[i], i == selectedOption, i);
        }
    }

    function drawOption(dc, w, centerY, height, label, isSelected, optionIndex) {
        var marginX = w * 7 / 100;
        var rectX   = marginX;
        var rectW   = w - marginX * 2;
        var rectY   = centerY - height / 2;

        // Background — slightly brighter when highlighted
        if (isSelected) {
            dc.setColor(0x303030, 0x303030);
        } else {
            dc.setColor(0x1A1A1A, 0x1A1A1A);
        }
        dc.fillRoundedRectangle(rectX, rectY, rectW, height, 8);

        // Yellow outline ring when highlighted (drawn 2px thick)
        if (isSelected) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rectX,     rectY,     rectW,     height,     8);
            dc.drawRoundedRectangle(rectX + 1, rectY + 1, rectW - 2, height - 2, 7);
        }

        // Icon + label inside the box
        var iconX = rectX + height / 2;
        drawIcon(dc, iconX, centerY, optionIndex);

        var textColor = (optionIndex == 3) ? Gfx.COLOR_RED : Gfx.COLOR_WHITE;
        dc.setColor(textColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(rectX + rectW * 3 / 5, centerY, Gfx.FONT_TINY, label,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // Icons drawn from primitives — no bitmap resources needed.
    function drawIcon(dc, cx, cy, optionIndex) {
        var s = 7;
        if (optionIndex == 0) {
            // RESUME: right-pointing play triangle
            dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
            dc.fillPolygon([
                [cx - s / 2, cy - s],
                [cx - s / 2, cy + s],
                [cx + s,     cy]
            ]);
        } else if (optionIndex == 1) {
            // SAVE: down arrow with stem
            dc.setColor(Gfx.COLOR_BLUE, Gfx.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 2, cy - s, 4, s);
            dc.fillPolygon([
                [cx - s, cy],
                [cx + s, cy],
                [cx,     cy + s]
            ]);
        } else if (optionIndex == 2) {
            // LATER: clock outline + hands
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, s);
            dc.drawLine(cx, cy, cx,         cy - s + 2);
            dc.drawLine(cx, cy, cx + s - 3, cy);
        } else if (optionIndex == 3) {
            // DISCARD: X (drawn as two thicker lines)
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(cx - s, cy - s, cx + s, cy + s);
            dc.drawLine(cx - s + 1, cy - s, cx + s + 1, cy + s);
            dc.drawLine(cx - s, cy + s, cx + s, cy - s);
            dc.drawLine(cx - s + 1, cy + s, cx + s + 1, cy - s);
        }
    }

    function onShow() {}
    function onHide() {}
}

// ── MatchMenuDelegate ────────────────────────────────────────
class MatchMenuDelegate extends Ui.InputDelegate {

    var view;
    var engine;
    var manager;

    function initialize(menuView, eng, mgr) {
        InputDelegate.initialize();
        view    = menuView;
        engine  = eng;
        manager = mgr;
    }

    function onTap(clickEvent) {
        if (view == null || view.optionYs == null) { return true; }

        var y         = clickEvent.getCoordinates()[1];
        var tolerance = view.optionH / 2 + 4;

        for (var i = 0; i < view.optionYs.size(); i++) {
            if (y >= view.optionYs[i] - tolerance && y <= view.optionYs[i] + tolerance) {
                view.selectedOption = i;
                Ui.requestUpdate();
                executeOption(i);
                return true;
            }
        }
        return true;
    }

    function onSwipe(swipeEvent) {
        if (view == null) { return true; }
        var dir = swipeEvent.getDirection();
        if (dir == Ui.SWIPE_DOWN) {
            if (view.selectedOption < 3) {
                view.selectedOption += 1;
                Ui.requestUpdate();
            }
        } else if (dir == Ui.SWIPE_UP) {
            if (view.selectedOption > 0) {
                view.selectedOption -= 1;
                Ui.requestUpdate();
            }
        }
        return true;
    }

    // Pressing BACK confirms the highlighted option (Garmin convention).
    function onBack() {
        if (view == null) { return true; }
        executeOption(view.selectedOption);
        return true;
    }

    function onKey(keyEvent) {
        if (view == null) { return true; }
        executeOption(view.selectedOption);
        return true;
    }

    function executeOption(option) {
        if (option == 0) {
            // RESUME — pop self, back to the match
            Ui.popView(Ui.SLIDE_DOWN);
        } else if (option == 1) {
            // SAVE — pop self, push PostMatch (which saves activity on exit)
            Ui.popView(Ui.SLIDE_IMMEDIATE);
            var pmView = new PostMatchView(engine, manager);
            Ui.pushView(
                pmView,
                new PostMatchDelegate(pmView, engine, manager),
                Ui.SLIDE_LEFT
            );
        } else if (option == 2) {
            // LATER — leave app with match saved for resume next launch.
            // v1.1.4: explicitly save state here as a safety net, in case
            // the user reaches LATER without ever scoring a point (the
            // per-point save in MainDelegate would never have fired).
            if (engine != null) {
                MatchPersistence.saveState(engine);
            }
            // Stack typically: [Setup, Main, MatchMenu] (fresh)
            //              or: [Main, MatchMenu]        (resumed)
            // Pop everything to exit cleanly.
            Ui.popView(Ui.SLIDE_RIGHT);
            Ui.popView(Ui.SLIDE_IMMEDIATE);
            Ui.popView(Ui.SLIDE_IMMEDIATE);
        } else if (option == 3) {
            // DISCARD — show confirmation first
            var confirmView = new DiscardConfirmView();
            Ui.pushView(
                confirmView,
                new DiscardConfirmDelegate(confirmView, engine, manager),
                Ui.SLIDE_LEFT
            );
        }
    }
}

// ── DiscardConfirmView — "Are you sure?" for discard ─────────
class DiscardConfirmView extends Ui.View {

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

        var titleY = h * 17 / 100;
        var subY   = titleY + dc.getFontHeight(Gfx.FONT_SMALL) + 2;

        dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, titleY, Gfx.FONT_SMALL, "DISCARD?",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, subY, Gfx.FONT_XTINY, "Match will not be saved",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // Buttons
        yesY = h * 37 / 100;
        yesH = h * 14 / 100;
        noY  = h * 60 / 100;
        noH  = h * 14 / 100;
        var btnW = w * 32 / 100;
        var btnX = w / 2 - btnW / 2;

        // YES — red filled (destructive)
        dc.setColor(Gfx.COLOR_DK_RED, Gfx.COLOR_DK_RED);
        dc.fillRoundedRectangle(btnX, yesY, btnW, yesH, 8);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, yesY + yesH / 2, Gfx.FONT_SMALL, "YES",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // NO — green outline (safe back)
        dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(btnX, noY, btnW, noH);
        dc.drawText(w / 2, noY + noH / 2, Gfx.FONT_SMALL, "NO",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    function onShow() {}
    function onHide() {}
}

class DiscardConfirmDelegate extends Ui.InputDelegate {

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
        var y   = clickEvent.getCoordinates()[1];
        var pad = 10;

        if (view.yesH > 0 && y >= view.yesY - pad && y <= view.yesY + view.yesH + pad) {
            discardMatch();
            return true;
        }
        if (view.noH > 0 && y >= view.noY - pad && y <= view.noY + view.noH + pad) {
            Ui.popView(Ui.SLIDE_DOWN);
            return true;
        }
        return true;
    }

    // Treat hardware buttons on the discard confirmation as NO.
    function onBack() {
        Ui.popView(Ui.SLIDE_DOWN);
        return true;
    }

    function onKey(keyEvent) {
        Ui.popView(Ui.SLIDE_DOWN);
        return true;
    }

    function discardMatch() {
        // Drop the activity recording without saving to Garmin Connect.
        if (manager != null) {
            manager.discardSession();
        }
        MatchPersistence.clearState();

        // Stack on entry: [Setup, Main, MatchMenu, DiscardConfirm]
        // Pop everything back to Setup; user gets a fresh setup screen.
        Ui.popView(Ui.SLIDE_RIGHT);     // pop DiscardConfirm
        Ui.popView(Ui.SLIDE_IMMEDIATE); // pop MatchMenu
        Ui.popView(Ui.SLIDE_IMMEDIATE); // pop MainView → SetupView
    }
}
