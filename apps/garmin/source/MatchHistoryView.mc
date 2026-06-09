// ============================================================
// MatchHistoryView.mc — Browse Match History
// MatchMind Tennis Tracker for Vivoactive 6
// ============================================================
// v1.3: shows the last 5 saved matches one at a time.
// Swipe LEFT  → older match
// Swipe RIGHT → newer match
// Back button → return to Setup
//
// Each match card shows:
//   Date · Singles/Doubles
//   YOU WIN! / OPP WON
//   ─────────────────
//   Sets    6-3 4-6
//   Pts W/L 45 / 38
//   Errors  12
//   D.Faults 3
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Time;
using Toybox.Time.Gregorian;

class MatchHistoryView extends Ui.View {

    var currentIdx;      // 0 = most recent
    var matchCount;
    var confirmDelete;   // true = show YES/NO overlay

    // Tap zones for delete confirmation — set during draw, read by delegate
    var confirmYesY;
    var confirmNoY;
    var confirmBtnH;
    var deleteBtnY;      // tap zone for the DELETE button itself
    var deleteBtnH;

    function initialize() {
        View.initialize();
        currentIdx    = 0;
        matchCount    = MatchHistory.getCount();
        confirmDelete = false;
        confirmYesY   = 0;
        confirmNoY    = 0;
        confirmBtnH   = 0;
        deleteBtnY    = 0;
        deleteBtnH    = 0;
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, h);

        if (matchCount == 0) {
            drawEmpty(dc, w, h);
        } else if (confirmDelete) {
            drawConfirm(dc, w, h);
        } else {
            drawMatch(dc, w, h);
        }
    }

    // ── Empty state ───────────────────────────────────────────
    function drawEmpty(dc, w, h) {
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 35 / 100, Gfx.FONT_TINY, "HISTORY",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 52 / 100, Gfx.FONT_XTINY, "No matches yet",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w / 2, h * 62 / 100, Gfx.FONT_XTINY, "Play and save a match first",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // ── Match card ────────────────────────────────────────────
    function drawMatch(dc, w, h) {
        var match = MatchHistory.getMatch(currentIdx);
        if (match == null) { return; }

        var cx = w / 2;

        // ── Header: HISTORY + index ───────────────────────────
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 8 / 100, Gfx.FONT_XTINY, "HISTORY",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        var idxStr = (currentIdx + 1).toString() + " of " + matchCount.toString();
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 15 / 100, Gfx.FONT_XTINY, idxStr,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // ── Date + match type ─────────────────────────────────
        var dateStr = _formatDate(match["date"]);
        var mtype   = match["mtype"];
        var typeStr = (mtype != null && mtype.equals("doubles")) ? "Doubles" : "Singles";
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 23 / 100, Gfx.FONT_XTINY, dateStr + "  " + typeStr,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // ── Result ────────────────────────────────────────────
        var won = match["won"];
        var playerWon = (won != null && won == 1);
        dc.setColor(playerWon ? Gfx.COLOR_GREEN : Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 32 / 100, Gfx.FONT_SMALL,
            playerWon ? "YOU WIN!" : "OPP WON",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // ── Divider ───────────────────────────────────────────
        dc.setColor(0x333333, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(cx - 55, h * 39 / 100, cx + 55, h * 39 / 100);

        // ── Stats rows ────────────────────────────────────────
        var rowGap = dc.getFontHeight(Gfx.FONT_TINY) + 4;
        var lx     = cx - (w * 12 / 100);  // label right edge
        var vx     = cx + (w * 4 / 100);   // value left edge
        var y      = h * 41 / 100;

        // Set scores — show full detail string if available
        var setScores = match["sets"];
        var setsP     = match["setsP"];
        var setsO     = match["setsO"];
        var setsVal;
        if (setScores != null && !setScores.equals("")) {
            setsVal = setScores;
        } else if (setsP != null && setsO != null) {
            setsVal = setsP.toString() + "-" + setsO.toString();
        } else {
            setsVal = "--";
        }
        _drawRow(dc, lx, vx, y, "Sets", setsVal);     y += rowGap;

        // Points won / lost
        var ptsW   = match["ptsW"];
        var ptsL   = match["ptsL"];
        var ptsStr = (ptsW != null && ptsL != null)
            ? ptsW.toString() + " / " + ptsL.toString() : "--";
        _drawRow(dc, lx, vx, y, "Pts W/L", ptsStr);   y += rowGap;

        // Errors
        var err = match["err"];
        _drawRow(dc, lx, vx, y, "Errors",   err != null ? err.toString() : "--");  y += rowGap;

        // Double faults
        var df = match["df"];
        _drawRow(dc, lx, vx, y, "D.Faults", df  != null ? df.toString()  : "--");

        // ── DELETE button ─────────────────────────────────────
        deleteBtnH = dc.getFontHeight(Gfx.FONT_XTINY) + 6;
        deleteBtnY = h * 80 / 100;
        var delBtnW = w * 36 / 100;
        dc.setColor(0x550000, 0x550000);
        dc.fillRoundedRectangle(cx - delBtnW / 2, deleteBtnY, delBtnW, deleteBtnH, 6);
        dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, deleteBtnY + deleteBtnH / 2, Gfx.FONT_XTINY, "DELETE",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // ── Swipe hint ────────────────────────────────────────
        if (matchCount > 1) {
            var hint;
            if (currentIdx == 0) {
                hint = "< older";
            } else if (currentIdx == matchCount - 1) {
                hint = "newer >";
            } else {
                hint = "newer >  < older";
            }
            dc.setColor(0x444444, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 91 / 100, Gfx.FONT_XTINY, hint,
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ── Delete confirmation overlay ───────────────────────────
    function drawConfirm(dc, w, h) {
        var cx = w / 2;
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 28 / 100, Gfx.FONT_SMALL, "Delete?",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 38 / 100, Gfx.FONT_XTINY, "This match will be removed",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        var btnW = w * 28 / 100;
        confirmBtnH = h * 13 / 100;
        confirmYesY = h * 53 / 100;
        confirmNoY  = h * 70 / 100;
        var btnX    = cx - btnW / 2;

        // YES — red
        dc.setColor(Gfx.COLOR_DK_RED, Gfx.COLOR_DK_RED);
        dc.fillRoundedRectangle(btnX, confirmYesY, btnW, confirmBtnH, 8);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, confirmYesY + confirmBtnH / 2, Gfx.FONT_SMALL, "YES",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // NO — dark grey
        dc.setColor(0x333333, 0x333333);
        dc.fillRoundedRectangle(btnX, confirmNoY, btnW, confirmBtnH, 8);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, confirmNoY + confirmBtnH / 2, Gfx.FONT_SMALL, "NO",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // ── Helpers ───────────────────────────────────────────────

    function _drawRow(dc, lx, vx, y, label, value) {
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(lx, y, Gfx.FONT_TINY, label,
            Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(vx, y, Gfx.FONT_TINY, value,
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    function _formatDate(timestamp) {
        if (timestamp == null) { return "--/--"; }
        try {
            var moment = new Time.Moment(timestamp);
            var info   = Gregorian.info(moment, Time.FORMAT_SHORT);
            return info.day.format("%02d") + "/" + info.month.format("%02d");
        } catch (e) {
            return "--/--";
        }
    }

    function onShow() {}
    function onHide() {}
}

// ── MatchHistoryDelegate ─────────────────────────────────────
class MatchHistoryDelegate extends Ui.InputDelegate {

    var view;

    function initialize(histView) {
        InputDelegate.initialize();
        view = histView;
    }

    function onTap(clickEvent) {
        if (view == null) { return true; }
        var y = clickEvent.getCoordinates()[1];

        if (view.confirmDelete) {
            // Handle YES / NO taps
            var pad = 8;
            if (y >= view.confirmYesY - pad && y <= view.confirmYesY + view.confirmBtnH + pad) {
                // YES — delete this match
                MatchHistory.deleteMatch(view.currentIdx);
                view.matchCount = MatchHistory.getCount();
                // Adjust index if we deleted the last item
                if (view.currentIdx >= view.matchCount && view.currentIdx > 0) {
                    view.currentIdx -= 1;
                }
                view.confirmDelete = false;
            } else if (y >= view.confirmNoY - pad && y <= view.confirmNoY + view.confirmBtnH + pad) {
                // NO — cancel
                view.confirmDelete = false;
            }
            Ui.requestUpdate();
            return true;
        }

        // Tap DELETE button
        if (view.deleteBtnH > 0 &&
            y >= view.deleteBtnY - 6 && y <= view.deleteBtnY + view.deleteBtnH + 6) {
            view.confirmDelete = true;
            Ui.requestUpdate();
        }
        return true;
    }

    // Swipe LEFT = go to older match (higher index)
    // Swipe RIGHT = go to newer match (lower index)
    function onSwipe(swipeEvent) {
        if (view == null) { return true; }
        // Cancel delete confirmation on any swipe
        if (view.confirmDelete) {
            view.confirmDelete = false;
            Ui.requestUpdate();
            return true;
        }
        var dir = swipeEvent.getDirection();
        if (dir == Ui.SWIPE_LEFT && view.currentIdx < view.matchCount - 1) {
            view.currentIdx += 1;
            Ui.requestUpdate();
        } else if (dir == Ui.SWIPE_RIGHT && view.currentIdx > 0) {
            view.currentIdx -= 1;
            Ui.requestUpdate();
        }
        return true;
    }

    function onBack() {
        if (view != null && view.confirmDelete) {
            view.confirmDelete = false;
            Ui.requestUpdate();
            return true;
        }
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }

    function onKey(keyEvent) {
        if (view != null && view.confirmDelete) {
            view.confirmDelete = false;
            Ui.requestUpdate();
            return true;
        }
        Ui.popView(Ui.SLIDE_RIGHT);
        return true;
    }
}
