// ============================================================
// TennisMatchEngine.mc — Core Scoring Logic
// Garmin Tennis Tracker for Vivoactive 6
// ============================================================

using Toybox.System as Sys;

class TennisMatchEngine {

    // ── Input type constants ─────────────────────────────────
    const WON          = 0;
    const ERROR        = 1;
    const DOUBLE_FAULT = 2;

    // ── Match configuration ──────────────────────────────────
    var matchFormat;           // 0 = Sets, 1 = Tiebreak only, 2 = Super TB only
    var setsToWin;
    var tiebreakEnabled;
    var superTiebreakFinalSet;
    var matchType;             // v1.2: "singles" or "doubles" (analysis label)

    // ── Match state ──────────────────────────────────────────
    var player;
    var opponent;
    var inTiebreak;
    var inSuperTiebreak;
    var matchOver;
    var history;
    var setHistory;

    // ── Serve tracking ───────────────────────────────────────
    var playerServing;         // true = player is serving this point
    var tiebreakPointsPlayed;  // points played in current tiebreak (drives server rotation)
    var tiebreakFirstServer;   // playerServing value when tiebreak started

    // ── Change-over indicator (v1.1.4) ───────────────────────
    // Tennis rule: switch ends after every odd-numbered game of the set,
    // and every 6 points in a tiebreak. Set true when due, cleared at the
    // start of the next handleInput.
    var needsChangeover;

    // ── Per-set captured stats (v1.1.5) ──────────────────────
    // Snapshots of the just-completed set, written to FIT lap fields by
    // the activity manager. Reset to null after they're consumed.
    //   lastSetTiebreakResult: 0=no tiebreak in this set
    //                          1=tiebreak, player won
    //                          2=tiebreak, player lost
    var lastSetWinners;
    var lastSetUnforcedErrors;
    var lastSetDoubleFaults;
    var lastSetTiebreakResult;

    // ── Timer ────────────────────────────────────────────────
    var startTime;

    // ─────────────────────────────────────────────────────────
    // initialize(config)
    // ─────────────────────────────────────────────────────────
    function initialize(config) {
        matchFormat           = config.hasKey(:matchFormat)           ? config[:matchFormat]           : 0;
        setsToWin             = config.hasKey(:setsToWin)             ? config[:setsToWin]             : 2;
        tiebreakEnabled       = config.hasKey(:tiebreakEnabled)       ? config[:tiebreakEnabled]       : true;
        superTiebreakFinalSet = config.hasKey(:superTiebreakFinalSet) ? config[:superTiebreakFinalSet] : true;
        playerServing         = config.hasKey(:playerServesFirst)     ? config[:playerServesFirst]     : true;
        matchType             = config.hasKey(:matchType)             ? config[:matchType]             : "singles";

        player   = newPlayer(true);
        opponent = newPlayer(false);

        matchOver              = false;
        history                = [];
        setHistory             = [];
        tiebreakPointsPlayed   = 0;
        tiebreakFirstServer    = playerServing;
        needsChangeover        = false;
        lastSetWinners         = 0;
        lastSetUnforcedErrors  = 0;
        lastSetDoubleFaults    = 0;
        lastSetTiebreakResult  = 0;
        startTime              = Sys.getTimer();

        // ── Format-specific startup ──────────────────────────
        if (matchFormat == 1) {
            // Tiebreak only — jump straight into a tiebreak, 1 to win
            inTiebreak      = true;
            inSuperTiebreak = false;
            setsToWin       = 1;
        } else if (matchFormat == 2) {
            // Super tiebreak only — jump straight into a super TB, 1 to win
            inTiebreak      = false;
            inSuperTiebreak = true;
            setsToWin       = 1;
        } else {
            // Normal sets
            inTiebreak      = false;
            inSuperTiebreak = false;
        }
    }

    // ─────────────────────────────────────────────────────────
    // newPlayer(isPlayer)
    // ─────────────────────────────────────────────────────────
    function newPlayer(isPlayer) {
        return {
            :isPlayer           => isPlayer,
            :points             => 0,
            :games              => 0,
            :sets               => 0,
            :winners            => 0,
            :unforcedErrors     => 0,
            :doubleFaults       => 0,
            :servePtsPlayed     => 0,   // points played while serving
            :servePtsWon        => 0,   // points won while serving
            :returnPtsPlayed    => 0,   // points played while returning
            :returnPtsWon       => 0,   // points won while returning
            // v1.1.5: per-set running counters (reset on set end)
            :setWinners         => 0,
            :setUnforcedErrors  => 0,
            :setDoubleFaults    => 0,
            // v1.1.5: match-total tiebreak counters
            :tiebreakPointsWon  => 0,
            :tiebreakPointsLost => 0,
            :tiebreaksWon       => 0
        };
    }

    // ─────────────────────────────────────────────────────────
    // handleInput(type)
    // ─────────────────────────────────────────────────────────
    function handleInput(type) {
        if (matchOver) { return; }

        // v1.1.4: clear the changeover flag when the next point starts.
        needsChangeover = false;

        saveState();

        // v1.1.5: also bump per-set counters and tiebreak match-level counters.
        var inAnyTiebreak = inTiebreak || inSuperTiebreak;

        if (type == WON) {
            player[:winners] += 1;
            player[:setWinners] += 1;
            if (inAnyTiebreak) { player[:tiebreakPointsWon] += 1; }
            awardPoint(player, opponent);
        } else if (type == ERROR) {
            player[:unforcedErrors] += 1;
            player[:setUnforcedErrors] += 1;
            if (inAnyTiebreak) { player[:tiebreakPointsLost] += 1; }
            awardPoint(opponent, player);
        } else if (type == DOUBLE_FAULT) {
            player[:doubleFaults] += 1;
            player[:setDoubleFaults] += 1;
            if (inAnyTiebreak) { player[:tiebreakPointsLost] += 1; }
            awardPoint(opponent, player);
        }
    }

    // ─────────────────────────────────────────────────────────
    // recordServePoint(winner)
    // Called at the start of every awardPoint — records serve/return
    // stats and advances the tiebreak server rotation.
    // ─────────────────────────────────────────────────────────
    function recordServePoint(winner) {
        if (playerServing) {
            // Player is serving this point
            player[:servePtsPlayed]   += 1;
            opponent[:returnPtsPlayed] += 1;
            if (winner[:isPlayer]) {
                player[:servePtsWon] += 1;
            } else {
                opponent[:returnPtsWon] += 1;
            }
        } else {
            // Opponent is serving this point
            opponent[:servePtsPlayed] += 1;
            player[:returnPtsPlayed]  += 1;
            if (!winner[:isPlayer]) {
                opponent[:servePtsWon] += 1;
            } else {
                player[:returnPtsWon] += 1;
            }
        }

        // ── Tiebreak server rotation ─────────────────────────
        // Pattern: first server serves 1 point, then alternate every 2.
        // Switch happens when tiebreakPointsPlayed becomes odd (1, 3, 5...).
        if (inTiebreak || inSuperTiebreak) {
            tiebreakPointsPlayed += 1;
            if (tiebreakPointsPlayed % 2 == 1) {
                playerServing = !playerServing;
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // awardPoint(winner, loser)
    // ─────────────────────────────────────────────────────────
    function awardPoint(winner, loser) {

        // Record serve/return stats before any state changes
        recordServePoint(winner);

        // ── Super tiebreak ───────────────────────────────────
        if (inSuperTiebreak) {
            winner[:points] += 1;
            // v1.1.4: changeover every 6 points in tiebreak
            var totalSTPts = player[:points] + opponent[:points];
            if (totalSTPts > 0 && totalSTPts % 6 == 0) {
                needsChangeover = true;
            }
            checkSuperTiebreakWin(winner, loser);
            return;
        }

        // ── Regular tiebreak ─────────────────────────────────
        if (inTiebreak) {
            winner[:points] += 1;
            // v1.1.4: changeover every 6 points in tiebreak
            var totalTBPts = player[:points] + opponent[:points];
            if (totalTBPts > 0 && totalTBPts % 6 == 0) {
                needsChangeover = true;
            }
            checkTiebreakWin(winner, loser);
            return;
        }

        // ── Normal scoring ───────────────────────────────────
        var wp = winner[:points];
        var lp = loser[:points];

        if (wp == 3 && lp == 3) {
            winner[:points] = 4;
        } else if (wp == 4) {
            winGame(winner, loser);
        } else if (wp == 3 && lp == 4) {
            loser[:points] = 3;
        } else {
            winner[:points] += 1;
            if (winner[:points] == 4 && loser[:points] < 3) {
                winGame(winner, loser);
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // winGame(winner, loser)
    // Awards a game, switches server, checks for set win.
    // ─────────────────────────────────────────────────────────
    function winGame(winner, loser) {
        winner[:games]       += 1;
        winner[:points]       = 0;
        loser[:points]        = 0;
        inTiebreak            = false;
        playerServing         = !playerServing;  // server switches after every game
        tiebreakPointsPlayed  = 0;

        // v1.1.4: change ends after every odd-numbered game of the set.
        // Total games in the current set = sum of both players' games.
        var totalGamesInSet = player[:games] + opponent[:games];
        if (totalGamesInSet % 2 == 1) {
            needsChangeover = true;
        }

        checkSetWin(winner, loser);
    }

    // ─────────────────────────────────────────────────────────
    // checkSetWin(winner, loser)
    // ─────────────────────────────────────────────────────────
    function checkSetWin(winner, loser) {
        var wg = winner[:games];
        var lg = loser[:games];

        // ── Normal tiebreak at 6-6? ──────────────────────────
        if (tiebreakEnabled && wg == 6 && lg == 6) {
            inTiebreak           = true;
            tiebreakFirstServer  = playerServing;
            tiebreakPointsPlayed = 0;
            return;
        }

        // ── Standard set win ─────────────────────────────────
        if (wg >= 6 && (wg - lg) >= 2) {
            addSetToHistory(winner);
            winner[:sets] += 1;
            captureSetEnd(0);  // v1.1.5: no tiebreak in this set
            resetAfterSet();
            checkMatchWin(winner);
            // v1.1.7: super tiebreak now starts AT the next set if applicable
            enterSuperTBIfFinalSet();
        }
    }

    // ─────────────────────────────────────────────────────────
    // checkTiebreakWin(winner, loser)
    // ─────────────────────────────────────────────────────────
    function checkTiebreakWin(winner, loser) {
        var wp = winner[:points];
        var lp = loser[:points];

        if (wp >= 7 && (wp - lp) >= 2) {
            addSetToHistory(winner);
            inTiebreak           = false;
            playerServing        = !tiebreakFirstServer;  // receiver at TB start now serves
            tiebreakPointsPlayed = 0;
            winner[:sets]        += 1;

            // v1.1.5: tiebreak result for this set + match-level count
            if (winner[:isPlayer]) {
                player[:tiebreaksWon] += 1;
                captureSetEnd(1);
            } else {
                captureSetEnd(2);
            }

            resetAfterSet();
            checkMatchWin(winner);
            // v1.1.7: super tiebreak now starts AT the next set if applicable
            enterSuperTBIfFinalSet();
        }
    }

    // ─────────────────────────────────────────────────────────
    // checkSuperTiebreakWin(winner, loser)
    // ─────────────────────────────────────────────────────────
    function checkSuperTiebreakWin(winner, loser) {
        var wp = winner[:points];
        var lp = loser[:points];

        if (wp >= 10 && (wp - lp) >= 2) {
            addSetToHistory(winner);
            inSuperTiebreak      = false;
            playerServing        = !tiebreakFirstServer;
            tiebreakPointsPlayed = 0;
            winner[:sets]        += 1;

            // v1.1.5: super tiebreak counts as a tiebreak for the result
            if (winner[:isPlayer]) {
                player[:tiebreaksWon] += 1;
                captureSetEnd(1);
            } else {
                captureSetEnd(2);
            }

            resetAfterSet();
            checkMatchWin(winner);
        }
    }

    // ─────────────────────────────────────────────────────────
    // addSetToHistory(winner)
    // ─────────────────────────────────────────────────────────
    function addSetToHistory(winner) {
        var pScore;
        var oScore;

        if (inSuperTiebreak) {
            // Always store actual super tiebreak points
            pScore = player[:points];
            oScore = opponent[:points];
        } else if (inTiebreak) {
            if (matchFormat == 1) {
                // Standalone tiebreak — store actual score (e.g. 7-5, 9-7)
                pScore = player[:points];
                oScore = opponent[:points];
            } else if (winner[:isPlayer]) {
                // In-set tiebreak — tennis convention 7-6 / 6-7
                pScore = 7; oScore = 6;
            } else {
                pScore = 6; oScore = 7;
            }
        } else {
            pScore = player[:games];
            oScore = opponent[:games];
        }

        setHistory.add({:p => pScore, :o => oScore});
    }

    // ─────────────────────────────────────────────────────────
    // resetAfterSet()
    // ─────────────────────────────────────────────────────────
    function resetAfterSet() {
        player[:games]    = 0;
        player[:points]   = 0;
        opponent[:games]  = 0;
        opponent[:points] = 0;

        // v1.1.5: clear per-set counters so the next set starts fresh
        player[:setWinners]        = 0;
        player[:setUnforcedErrors] = 0;
        player[:setDoubleFaults]   = 0;
        opponent[:setWinners]        = 0;
        opponent[:setUnforcedErrors] = 0;
        opponent[:setDoubleFaults]   = 0;
    }

    // ─────────────────────────────────────────────────────────
    // enterSuperTBIfFinalSet()  — v1.1.7
    // Called after a set ends + resetAfterSet(). If the match isn't
    // over AND the upcoming set is the deciding set in a best-of-N
    // with superTiebreakFinalSet=true, convert it to a super tiebreak
    // BEFORE any points are played. This fixes the v1.1.5/1.1.6 bug
    // where set 3 started as a normal set and only switched to super
    // TB after the first game was won, with confusing score resets.
    //
    // For best-of-3 with super TB: triggers when totalSets == 2 (1-1).
    // For best-of-5 with super TB: triggers when totalSets == 4 (2-2).
    // ─────────────────────────────────────────────────────────
    function enterSuperTBIfFinalSet() {
        if (matchOver) { return; }
        if (!superTiebreakFinalSet) { return; }
        if (setsToWin < 2) { return; }  // not valid for single-set formats

        var totalSets = player[:sets] + opponent[:sets];
        if (totalSets == (setsToWin * 2 - 2)) {
            inSuperTiebreak      = true;
            tiebreakFirstServer  = playerServing;
            tiebreakPointsPlayed = 0;
            // games + points already reset to 0 by resetAfterSet()
        }
    }

    // ─────────────────────────────────────────────────────────
    // captureSetEnd(tiebreakResult)  — v1.1.5
    // Snapshot the just-finished set's stats so the FIT lap fields can
    // pick them up. tiebreakResult: 0=no tiebreak, 1=player won TB,
    // 2=player lost TB.
    // ─────────────────────────────────────────────────────────
    function captureSetEnd(tiebreakResult) {
        lastSetWinners        = player[:setWinners];
        lastSetUnforcedErrors = player[:setUnforcedErrors];
        lastSetDoubleFaults   = player[:setDoubleFaults];
        lastSetTiebreakResult = tiebreakResult;
    }

    // ─────────────────────────────────────────────────────────
    // checkMatchWin(winner)
    // ─────────────────────────────────────────────────────────
    function checkMatchWin(winner) {
        if (winner[:sets] >= setsToWin) {
            matchOver = true;
        }
    }

    // ─────────────────────────────────────────────────────────
    // undo()
    // ─────────────────────────────────────────────────────────
    function undo() {
        if (history.size() > 0) {
            var lastIdx = history.size() - 1;
            var prev    = history[lastIdx];

            // Rebuild history without the last entry (slice can return null on empty)
            var newHistory = [];
            for (var i = 0; i < lastIdx; i++) {
                newHistory.add(history[i]);
            }
            history = newHistory;

            player                = prev[:player];
            opponent              = prev[:opponent];
            inTiebreak            = prev[:inTiebreak];
            inSuperTiebreak       = prev[:inSuperTiebreak];
            matchOver             = prev[:matchOver];
            setHistory            = prev[:setHistory];
            playerServing         = prev[:playerServing];
            tiebreakPointsPlayed  = prev[:tiebreakPointsPlayed];
            tiebreakFirstServer   = prev[:tiebreakFirstServer];
            needsChangeover       = prev.hasKey(:needsChangeover)      ? prev[:needsChangeover]      : false;
            // v1.1.5 last-set captures
            lastSetWinners        = prev.hasKey(:lastSetWinners)        ? prev[:lastSetWinners]        : 0;
            lastSetUnforcedErrors = prev.hasKey(:lastSetUnforcedErrors) ? prev[:lastSetUnforcedErrors] : 0;
            lastSetDoubleFaults   = prev.hasKey(:lastSetDoubleFaults)   ? prev[:lastSetDoubleFaults]   : 0;
            lastSetTiebreakResult = prev.hasKey(:lastSetTiebreakResult) ? prev[:lastSetTiebreakResult] : 0;
        }
    }

    // ─────────────────────────────────────────────────────────
    // saveState()
    // ─────────────────────────────────────────────────────────
    function saveState() {
        var shCopy = [];
        for (var i = 0; i < setHistory.size(); i++) {
            shCopy.add(setHistory[i]);
        }

        history.add({
            :player                => clonePlayer(player),
            :opponent              => clonePlayer(opponent),
            :inTiebreak            => inTiebreak,
            :inSuperTiebreak       => inSuperTiebreak,
            :matchOver             => matchOver,
            :setHistory            => shCopy,
            :playerServing         => playerServing,
            :tiebreakPointsPlayed  => tiebreakPointsPlayed,
            :tiebreakFirstServer   => tiebreakFirstServer,
            :needsChangeover       => needsChangeover,
            // v1.1.5 last-set captures (so undo also restores them)
            :lastSetWinners        => lastSetWinners,
            :lastSetUnforcedErrors => lastSetUnforcedErrors,
            :lastSetDoubleFaults   => lastSetDoubleFaults,
            :lastSetTiebreakResult => lastSetTiebreakResult
        });

        if (history.size() > 50) {
            var newHistory = [];
            for (var i = 1; i < history.size(); i++) {
                newHistory.add(history[i]);
            }
            history = newHistory;
        }
    }

    // ─────────────────────────────────────────────────────────
    // clonePlayer(p)
    // ─────────────────────────────────────────────────────────
    function clonePlayer(p) {
        return {
            :isPlayer           => p[:isPlayer],
            :points             => p[:points],
            :games              => p[:games],
            :sets               => p[:sets],
            :winners            => p[:winners],
            :unforcedErrors     => p[:unforcedErrors],
            :doubleFaults       => p[:doubleFaults],
            :servePtsPlayed     => p[:servePtsPlayed],
            :servePtsWon        => p[:servePtsWon],
            :returnPtsPlayed    => p[:returnPtsPlayed],
            :returnPtsWon       => p[:returnPtsWon],
            // v1.1.5
            :setWinners         => p[:setWinners],
            :setUnforcedErrors  => p[:setUnforcedErrors],
            :setDoubleFaults    => p[:setDoubleFaults],
            :tiebreakPointsWon  => p[:tiebreakPointsWon],
            :tiebreakPointsLost => p[:tiebreakPointsLost],
            :tiebreaksWon       => p[:tiebreaksWon]
        };
    }

    // ─────────────────────────────────────────────────────────
    // getPointDisplay(p)
    // ─────────────────────────────────────────────────────────
    function getPointDisplay(p) {
        if (inTiebreak || inSuperTiebreak) {
            return p[:points].toString();
        }
        var labels = ["0", "15", "30", "40", "Ad"];
        var idx = p[:points];
        if (idx < 0) { idx = 0; }
        if (idx >= labels.size()) { idx = labels.size() - 1; }
        return labels[idx];
    }

    // ─────────────────────────────────────────────────────────
    // getElapsedSeconds()
    // ─────────────────────────────────────────────────────────
    function getElapsedSeconds() {
        return (Sys.getTimer() - startTime) / 1000;
    }

    // ─────────────────────────────────────────────────────────
    // getState() / restore(state) — for MatchPersistence
    //
    // IMPORTANT: CIQ Storage cannot serialize Symbol keys or
    // nested dictionaries. This function returns a completely
    // FLAT dictionary using only String keys and primitive
    // values (Number, Boolean). setHistory is stored as two
    // parallel arrays of Numbers (shP and shO).
    // ─────────────────────────────────────────────────────────
    function getState() {
        var elapsed = getElapsedSeconds().toNumber();

        // Flatten setHistory into two Number arrays
        var shP = [];
        var shO = [];
        for (var i = 0; i < setHistory.size(); i++) {
            shP.add(setHistory[i][:p]);
            shO.add(setHistory[i][:o]);
        }

        return {
            // Player fields
            "pPoints"          => player[:points],
            "pGames"           => player[:games],
            "pSets"            => player[:sets],
            "pWinners"         => player[:winners],
            "pErrors"          => player[:unforcedErrors],
            "pDFaults"         => player[:doubleFaults],
            "pSrvPlayed"       => player[:servePtsPlayed],
            "pSrvWon"          => player[:servePtsWon],
            "pRetPlayed"       => player[:returnPtsPlayed],
            "pRetWon"          => player[:returnPtsWon],
            // v1.1.5 player fields
            "pSetW"            => player[:setWinners],
            "pSetE"            => player[:setUnforcedErrors],
            "pSetD"            => player[:setDoubleFaults],
            "pTBPtsW"          => player[:tiebreakPointsWon],
            "pTBPtsL"          => player[:tiebreakPointsLost],
            "pTBsW"            => player[:tiebreaksWon],
            // Opponent fields
            "oPoints"          => opponent[:points],
            "oGames"           => opponent[:games],
            "oSets"            => opponent[:sets],
            "oWinners"         => opponent[:winners],
            "oErrors"          => opponent[:unforcedErrors],
            "oDFaults"         => opponent[:doubleFaults],
            "oSrvPlayed"       => opponent[:servePtsPlayed],
            "oSrvWon"          => opponent[:servePtsWon],
            "oRetPlayed"       => opponent[:returnPtsPlayed],
            "oRetWon"          => opponent[:returnPtsWon],
            // v1.1.5 opponent fields
            "oSetW"            => opponent[:setWinners],
            "oSetE"            => opponent[:setUnforcedErrors],
            "oSetD"            => opponent[:setDoubleFaults],
            "oTBPtsW"          => opponent[:tiebreakPointsWon],
            "oTBPtsL"          => opponent[:tiebreakPointsLost],
            "oTBsW"            => opponent[:tiebreaksWon],
            // Match state
            "inTiebreak"       => inTiebreak,
            "inSuperTB"        => inSuperTiebreak,
            "matchOver"        => matchOver,
            "matchFormat"      => matchFormat,
            "setsToWin"        => setsToWin,
            "tbEnabled"        => tiebreakEnabled,
            "superTBFinal"     => superTiebreakFinalSet,
            "matchType"        => matchType,
            "elapsed"          => elapsed,
            "serving"          => playerServing,
            "tbPtsPlayed"      => tiebreakPointsPlayed,
            "tbFirstServer"    => tiebreakFirstServer,
            "ndCh"             => needsChangeover,
            // v1.1.5 last-set captures
            "lsW"              => lastSetWinners,
            "lsE"              => lastSetUnforcedErrors,
            "lsD"              => lastSetDoubleFaults,
            "lsTB"             => lastSetTiebreakResult,
            // Set history as parallel Number arrays
            "shP"              => shP,
            "shO"              => shO
        };
    }

    function restore(state) {
        // Rebuild player dictionary from flat String keys
        player = {
            :isPlayer           => true,
            :points             => state["pPoints"],
            :games              => state["pGames"],
            :sets               => state["pSets"],
            :winners            => state["pWinners"],
            :unforcedErrors     => state["pErrors"],
            :doubleFaults       => state["pDFaults"],
            :servePtsPlayed     => state["pSrvPlayed"],
            :servePtsWon        => state["pSrvWon"],
            :returnPtsPlayed    => state["pRetPlayed"],
            :returnPtsWon       => state["pRetWon"],
            // v1.1.5 fields (with defaults if absent in older saved state)
            :setWinners         => state.hasKey("pSetW")   ? state["pSetW"]   : 0,
            :setUnforcedErrors  => state.hasKey("pSetE")   ? state["pSetE"]   : 0,
            :setDoubleFaults    => state.hasKey("pSetD")   ? state["pSetD"]   : 0,
            :tiebreakPointsWon  => state.hasKey("pTBPtsW") ? state["pTBPtsW"] : 0,
            :tiebreakPointsLost => state.hasKey("pTBPtsL") ? state["pTBPtsL"] : 0,
            :tiebreaksWon       => state.hasKey("pTBsW")   ? state["pTBsW"]   : 0
        };

        // Rebuild opponent dictionary from flat String keys
        opponent = {
            :isPlayer           => false,
            :points             => state["oPoints"],
            :games              => state["oGames"],
            :sets               => state["oSets"],
            :winners            => state["oWinners"],
            :unforcedErrors     => state["oErrors"],
            :doubleFaults       => state["oDFaults"],
            :servePtsPlayed     => state["oSrvPlayed"],
            :servePtsWon        => state["oSrvWon"],
            :returnPtsPlayed    => state["oRetPlayed"],
            :returnPtsWon       => state["oRetWon"],
            // v1.1.5 fields
            :setWinners         => state.hasKey("oSetW")   ? state["oSetW"]   : 0,
            :setUnforcedErrors  => state.hasKey("oSetE")   ? state["oSetE"]   : 0,
            :setDoubleFaults    => state.hasKey("oSetD")   ? state["oSetD"]   : 0,
            :tiebreakPointsWon  => state.hasKey("oTBPtsW") ? state["oTBPtsW"] : 0,
            :tiebreakPointsLost => state.hasKey("oTBPtsL") ? state["oTBPtsL"] : 0,
            :tiebreaksWon       => state.hasKey("oTBsW")   ? state["oTBsW"]   : 0
        };

        // Restore match state
        inTiebreak            = state["inTiebreak"];
        inSuperTiebreak       = state["inSuperTB"];
        matchOver             = state["matchOver"];
        matchFormat           = state.hasKey("matchFormat")   ? state["matchFormat"]   : 0;
        setsToWin             = state["setsToWin"];
        tiebreakEnabled       = state["tbEnabled"];
        superTiebreakFinalSet = state["superTBFinal"];
        matchType             = state.hasKey("matchType")     ? state["matchType"]     : "singles";
        playerServing         = state.hasKey("serving")       ? state["serving"]       : true;
        tiebreakPointsPlayed  = state.hasKey("tbPtsPlayed")   ? state["tbPtsPlayed"]   : 0;
        tiebreakFirstServer   = state.hasKey("tbFirstServer") ? state["tbFirstServer"] : true;
        needsChangeover       = state.hasKey("ndCh")          ? state["ndCh"]          : false;
        // v1.1.5 last-set captures
        lastSetWinners        = state.hasKey("lsW")  ? state["lsW"]  : 0;
        lastSetUnforcedErrors = state.hasKey("lsE")  ? state["lsE"]  : 0;
        lastSetDoubleFaults   = state.hasKey("lsD")  ? state["lsD"]  : 0;
        lastSetTiebreakResult = state.hasKey("lsTB") ? state["lsTB"] : 0;
        history               = [];

        // Reconstruct setHistory from parallel Number arrays
        var shP = state.hasKey("shP") ? state["shP"] : [];
        var shO = state.hasKey("shO") ? state["shO"] : [];
        setHistory = [];
        for (var i = 0; i < shP.size(); i++) {
            setHistory.add({:p => shP[i], :o => shO[i]});
        }

        // Reconstruct startTime from elapsed seconds
        var elapsed = state.hasKey("elapsed") ? state["elapsed"] : 0;
        startTime = Sys.getTimer() - (elapsed * 1000).toLong();
    }
}
