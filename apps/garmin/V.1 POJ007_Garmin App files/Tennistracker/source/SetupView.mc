// ============================================================
// SetupView.mc — Pre-Match Configuration Screen
// MatchMind Tennis Tracker for Vivoactive 6
// ============================================================
// v1.1.7: replaced the 4-toggle config (FORMAT / SETS / TIEBREAK /
// SUPER TB) with a single FORMAT preset selector that covers the
// real-world tennis formats. Cuts setup from 5 rows of decisions
// down to 2:
//
//   0  Best of 3       — 3 normal sets, tiebreak at 6-6 (singles
//                        standard, doubles finals, club tennis)
//   1  2 Sets + STB    — 2 sets + super tiebreak as decider
//                        (doubles compact / college / most pro doubles)
//   2  1 Set           — single set, tiebreak at 6-6 (quick match)
//   3  Super TB        — single 10-point super tiebreak
//
// Each preset derives the engine config (matchFormat / setsToWin /
// tiebreakEnabled / superTiebreakFinalSet) automatically on START.
//
// v1.1.2: Responsive layout. Row positions are computed from
// dc.getHeight() and the actual font height, so they adapt to
// however the real device renders text. The delegate receives
// the view by reference (no more Ui.getCurrentView()[0] casts —
// those crashed on real watches).
// ============================================================

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;

class SetupView extends Ui.View {

    // v1.2.1: preset index is now context-aware (Singles vs Doubles).
    // Both types have 3 options (index 0-2):
    //   Singles  0=1 Set  1=Best of 3  2=Super TB
    //   Doubles  0=1 Set  1=Best of 3+ST (2 sets + super TB decider)  2=Super TB
    var formatPreset;
    var playerServesFirst;

    // v1.2: match type for analysis later (Singles / Doubles).
    //   0 = singles, 1 = doubles
    var matchTypeIdx;

    // 0=TYPE, 1=FORMAT, 2=SERVES 1ST
    var selectedItem;

    // ── Layout values, computed each frame from dc dimensions ──
    var rowYs;          // Array of 2 y-positions for each row centre
    var rowSpacing;     // Vertical pitch between rows (used for tap zones)
    var startBtnY;      // Top of START button
    var startBtnH;      // Height of START button

    function initialize() {
        View.initialize();
        matchTypeIdx      = 0;       // Default: Singles
        formatPreset      = 0;       // Default: Best of 3
        playerServesFirst = true;
        selectedItem      = 0;
        rowYs             = null;
        rowSpacing        = 30;
        startBtnY         = 0;
        startBtnH         = 30;
    }

    function onLayout(dc) {}

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // ── Background ────────────────────────────────────────
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, h);

        // ── Compute responsive layout ────────────────────────
        // v1.2.1: rows use FONT_XTINY for both label and value so all
        // 3 rows + START button fit without crowding.
        var titleH    = dc.getFontHeight(Gfx.FONT_TINY);
        var subtitleH = dc.getFontHeight(Gfx.FONT_XTINY);
        var labelH    = dc.getFontHeight(Gfx.FONT_XTINY);
        var valueH    = dc.getFontHeight(Gfx.FONT_XTINY);
        var rowH      = labelH + valueH;
        rowSpacing    = rowH + 8;              // tighter gap between rows
        startBtnH     = titleH + 8;

        var titleY    = h * 5 / 100;
        var subtitleY = titleY + titleH;

        startBtnY = h - startBtnH - (h * 4 / 100);

        // 3 rows (TYPE, FORMAT, SERVES 1ST) distributed between subtitle
        // and START button. HISTORY is on a swipe-left page.
        var rowsTop      = subtitleY + subtitleH + 8;
        var rowsBottom   = startBtnY - 16;
        var availableH   = rowsBottom - rowsTop;
        var totalRowsH   = rowSpacing * 2;    // 2 gaps between 3 rows
        var extraSpace   = availableH - totalRowsH;
        var topPad       = (extraSpace > 0) ? extraSpace / 2 : 0;
        var firstRowY    = rowsTop + topPad + (rowH / 2);

        rowYs = [
            firstRowY,
            firstRowY + rowSpacing,
            firstRowY + rowSpacing * 2
        ];

        // ── Title ────────────────────────────────────────────
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, titleY, Gfx.FONT_TINY, "MatchMind", Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, subtitleY, Gfx.FONT_XTINY, "MATCH SETUP", Gfx.TEXT_JUSTIFY_CENTER);

        // ── TYPE row (v1.2) ──────────────────────────────────
        var typeLabels = ["Singles", "Doubles"];
        drawRow(dc, w, rowYs[0], "TYPE", typeLabels[matchTypeIdx], selectedItem == 0, false);

        // ── FORMAT row ────────────────────────────────────────
        // v1.2.1: labels are context-aware based on match type.
        var presetLabels;
        if (matchTypeIdx == 0) {
            // Singles
            presetLabels = ["1 Set", "Best of 3", "Super TB"];
        } else {
            // Doubles
            presetLabels = ["1 Set", "Best of 3+ST", "Super TB"];
        }
        drawRow(dc, w, rowYs[1], "FORMAT", presetLabels[formatPreset], selectedItem == 1, false);

        // ── Serves first ─────────────────────────────────────
        drawRow(dc, w, rowYs[2], "SERVES 1ST", playerServesFirst ? "You" : "Opp", selectedItem == 2, false);

        // ── History hint (v1.3) — swipe left to open ─────────
        // Small arrow at top-right edge to hint at the history page.
        var histCount = MatchHistory.getCount();
        var hintColor = (histCount > 0) ? 0x555555 : 0x333333;
        dc.setColor(hintColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w - 14, h / 2, Gfx.FONT_XTINY, ">",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // ── START button ─────────────────────────────────────
        var btnW       = w / 3;
        var btnX       = w / 2 - btnW / 2;
        var startColor = (selectedItem == 3) ? Gfx.COLOR_GREEN : Gfx.COLOR_DK_GREEN;
        dc.setColor(startColor, startColor);
        dc.fillRoundedRectangle(btnX, startBtnY, btnW, startBtnH, 8);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, startBtnY + startBtnH / 2, Gfx.FONT_SMALL, "START",
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    // Draws one config row, stacked layout:
    //   small grey LABEL on top
    //   white value below (same FONT_XTINY — compact so 3 rows + START fit)
    // y is the vertical centre of the whole row.
    function drawRow(dc, w, y, label, value, isSelected, isDisabled) {
        var labelH = dc.getFontHeight(Gfx.FONT_XTINY);
        var valueH = dc.getFontHeight(Gfx.FONT_XTINY);

        if (isSelected && !isDisabled) {
            dc.setColor(Gfx.COLOR_DK_BLUE, Gfx.COLOR_DK_BLUE);
            var hiH = rowSpacing - 2;
            var hiW = w * 70 / 100;
            dc.fillRoundedRectangle((w - hiW) / 2, y - hiH / 2, hiW, hiH, 6);
        }

        var labelColor = isDisabled ? 0x2A2A2A : Gfx.COLOR_LT_GRAY;
        var valueColor = isDisabled ? 0x2A2A2A : Gfx.COLOR_WHITE;

        var labelY = y - (valueH / 2) + 2;
        var valueY = y + (labelH / 2);

        dc.setColor(labelColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, labelY, Gfx.FONT_XTINY, label,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.setColor(valueColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, valueY, Gfx.FONT_XTINY, value,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    function onShow() {}
    function onHide() {}
}

// ── SetupDelegate ────────────────────────────────────────────
// v1.1.7: simplified — only FORMAT and SERVES 1ST rows now.
class SetupDelegate extends Ui.InputDelegate {

    var view;

    function initialize(setupView) {
        InputDelegate.initialize();
        view = setupView;
    }

    function onTap(clickEvent) {
        if (view == null || view.rowYs == null) {
            return true;  // layout not yet computed — ignore tap
        }

        var y = clickEvent.getCoordinates()[1];
        var tolerance = view.rowSpacing / 2;

        // Check the 2 config rows
        for (var i = 0; i < view.rowYs.size(); i++) {
            if (y >= view.rowYs[i] - tolerance && y <= view.rowYs[i] + tolerance) {
                handleRowTap(i);
                Ui.requestUpdate();
                return true;
            }
        }

        // Check the START button
        if (y >= view.startBtnY - 6 && y <= view.startBtnY + view.startBtnH + 6) {
            startMatch();
            return true;
        }

        return true;
    }

    function handleRowTap(rowIndex) {
        if (rowIndex == 0) {
            toggleMatchType();
        } else if (rowIndex == 1) {
            cyclePreset();
        } else if (rowIndex == 2) {
            toggleServesFirst();
        }
    }

    function openHistory() {
        var histView = new MatchHistoryView();
        Ui.pushView(histView, new MatchHistoryDelegate(histView), Ui.SLIDE_LEFT);
    }

    function onSwipe(swipeEvent) {
        if (view == null) { return true; }
        var dir = swipeEvent.getDirection();

        if (dir == Ui.SWIPE_DOWN) {
            if (view.selectedItem < 2) {   // 3 rows: 0-2
                view.selectedItem += 1;
            }
        } else if (dir == Ui.SWIPE_UP) {
            if (view.selectedItem > 0) {
                view.selectedItem -= 1;
            }
        } else if (dir == Ui.SWIPE_LEFT) {
            // v1.3: swipe left opens match history
            openHistory();
        }

        Ui.requestUpdate();
        return true;
    }

    function toggleMatchType() {
        view.matchTypeIdx = (view.matchTypeIdx == 0) ? 1 : 0;
        // Reset format to 0 (1 Set) when switching type — avoids carrying
        // over a preset index that means something different in the new type.
        view.formatPreset = 0;
    }

    function cyclePreset() {
        // v1.2.1: 3 options (0-2) for both Singles and Doubles.
        view.formatPreset = (view.formatPreset + 1) % 3;
    }

    function toggleServesFirst() {
        view.playerServesFirst = !view.playerServesFirst;
    }

    // v1.2.1: derive engine config from FORMAT preset + match type.
    // Both Singles and Doubles share the same preset indices (0-2):
    //   0  1 Set      → 1 set, tiebreak ON, no super TB (same for both types)
    //   1  Best of 3  → Singles: 3 sets, tiebreak ON, no super TB
    //                   Doubles: 2 sets, tiebreak ON, super TB decider
    //   2  Super TB   → single super tiebreak to 10 (same for both types)
    function configFromPreset(preset, matchType) {
        if (preset == 0) {
            // 1 Set — identical for Singles and Doubles
            return {
                :matchFormat           => 0,
                :setsToWin             => 1,
                :tiebreakEnabled       => true,
                :superTiebreakFinalSet => false
            };
        } else if (preset == 1) {
            if (matchType == 0) {
                // Singles — Best of 3: standard 3 sets, tiebreak at 6-6
                return {
                    :matchFormat           => 0,
                    :setsToWin             => 2,
                    :tiebreakEnabled       => true,
                    :superTiebreakFinalSet => false
                };
            } else {
                // Doubles — Best of 3+ST: 2 sets + super tiebreak decider
                return {
                    :matchFormat           => 0,
                    :setsToWin             => 2,
                    :tiebreakEnabled       => true,
                    :superTiebreakFinalSet => true
                };
            }
        } else {  // preset == 2 — Super TB Only (same for both types)
            return {
                :matchFormat           => 2,
                :setsToWin             => 1,
                :tiebreakEnabled       => false,
                :superTiebreakFinalSet => false
            };
        }
    }

    function startMatch() {
        var derived = configFromPreset(view.formatPreset, view.matchTypeIdx);
        var config = {
            :matchFormat           => derived[:matchFormat],
            :setsToWin             => derived[:setsToWin],
            :tiebreakEnabled       => derived[:tiebreakEnabled],
            :superTiebreakFinalSet => derived[:superTiebreakFinalSet],
            :playerServesFirst     => view.playerServesFirst,
            :matchType             => (view.matchTypeIdx == 0) ? "singles" : "doubles"
        };

        var engine  = new TennisMatchEngine(config);
        var manager = new TennisActivityManager();
        manager.startSession();

        // v1.1.4: save initial state immediately. Without this, a user who
        // starts a match but presses LATER before scoring a point has nothing
        // saved — the resume prompt never appears next launch.
        MatchPersistence.saveState(engine);

        var mainView = new MainView(engine, manager);
        Ui.pushView(
            mainView,
            new MainDelegate(mainView, engine, manager),
            Ui.SLIDE_LEFT
        );
    }
}
