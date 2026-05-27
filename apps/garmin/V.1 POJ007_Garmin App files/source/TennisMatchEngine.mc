// ============================================================
// TennisMatchEngine.mc — Core Scoring Logic
// Garmin Tennis Tracker for Vivoactive 6
// ============================================================
// This is the brain of the app. It handles:
//   - Point scoring (0, 15, 30, 40, deuce, advantage)
//   - Game and set counting
//   - Tiebreaks and super tiebreaks
//   - Undo (history stack)
//   - Match statistics (winners, errors, double faults)
// ============================================================

using Toybox.System as Sys;

class TennisMatchEngine {

    // ── Input type constants ─────────────────────────────────
    // Used by MainView to tell the engine what happened.
    const WON          = 0;  // Player won the point (winner / good shot)
    const ERROR        = 1;  // Player made an unforced error (opponent wins point)
    const DOUBLE_FAULT = 2;  // Player double-faulted (opponent wins point)

    // ── Match configuration ──────────────────────────────────
    var setsToWin;             // e.g. 2 = best of 3, 3 = best of 5
    var tiebreakEnabled;       // true/false — play tiebreak at 6-6?
    var superTiebreakFinalSet; // true/false — replace final set with super tiebreak (10 pts)?

    // ── Match state ──────────────────────────────────────────
    var player;          // Dictionary: the person wearing the watch
    var opponent;        // Dictionary: the person on the other side of the net
    var inTiebreak;      // true when a regular tiebreak is in progress
    var inSuperTiebreak; // true when a super tiebreak (match tiebreak) is in progress
    var matchOver;       // true once someone has won the required number of sets
    var history;         // Array of state snapshots for undo

    // ── Timer ────────────────────────────────────────────────
    var startTime;       // System.getTimer() value at match start (milliseconds)

    // ─────────────────────────────────────────────────────────
    // initialize(config)
    // Called once when a new match begins.
    // config = {:setsToWin => 2, :tiebreakEnabled => true, :superTiebreakFinalSet => true}
    // ─────────────────────────────────────────────────────────
    function initialize(config) {
        setsToWin             = config.hasKey(:setsToWin)             ? config[:setsToWin]             : 2;
        tiebreakEnabled       = config.hasKey(:tiebreakEnabled)       ? config[:tiebreakEnabled]       : true;
        superTiebreakFinalSet = config.hasKey(:superTiebreakFinalSet) ? config[:superTiebreakFinalSet] : true;

        player   = newPlayer();
        opponent = newPlayer();

        inTiebreak      = false;
        inSuperTiebreak = false;
        matchOver       = false;
        history         = [];

        // Record when the match started (milliseconds since device boot).
        // Use System.getTimer() — NOT System.getClockTime() — for elapsed time.
        startTime = Sys.getTimer();
    }

    // ─────────────────────────────────────────────────────────
    // newPlayer()
    // Returns a fresh player dictionary with all stats at zero.
    // ─────────────────────────────────────────────────────────
    function newPlayer() {
        return {
            :points        => 0,
            :games         => 0,
            :sets          => 0,
            :winners       => 0,
            :unforcedErrors => 0,
            :doubleFaults  => 0
        };
    }

    // ─────────────────────────────────────────────────────────
    // handleInput(type)
    // Main entry point called by MainView on every user gesture.
    // Saves state first (for undo), then resolves who wins the point.
    // ─────────────────────────────────────────────────────────
    function handleInput(type) {
        if (matchOver) { return; } // Ignore input after match ends

        saveState(); // Always snapshot before changing anything

        if (type == WON) {
            player[:winners] += 1;
            awardPoint(player, opponent);
        } else if (type == ERROR) {
            player[:unforcedErrors] += 1;
            awardPoint(opponent, player);
        } else if (type == DOUBLE_FAULT) {
            player[:doubleFaults] += 1;
            awardPoint(opponent, player);
        }
    }

    // ─────────────────────────────────────────────────────────
    // awardPoint(winner, loser)
    // Adds a point to winner and checks for game/set/match outcomes.
    // Handles tiebreak, super tiebreak, deuce, and advantage.
    // ─────────────────────────────────────────────────────────
    function awardPoint(winner, loser) {

        // ── Super tiebreak in progress ───────────────────────
        if (inSuperTiebreak) {
            winner[:points] += 1;
            checkSuperTiebreakWin(winner, loser);
            return;
        }

        // ── Regular tiebreak in progress ────────────────────
        if (inTiebreak) {
            winner[:points] += 1;
            checkTiebreakWin(winner, loser);
            return;
        }

        // ── Normal scoring (0, 15, 30, 40) ──────────────────
        // Points are stored as integers: 0, 1, 2, 3 = (0, 15, 30, 40)
        // 4 = advantage (only reached from deuce = both at 3)

        var wp = winner[:points];
        var lp = loser[:points];

        if (wp == 3 && lp == 3) {
            // Deuce: winner gets advantage (4)
            winner[:points] = 4;
        } else if (wp == 4) {
            // Winner had advantage — wins the game
            winGame(winner, loser);
        } else if (wp == 3 && lp == 4) {
            // Loser had advantage — back to deuce
            loser[:points] = 3;
        } else {
            // Normal progression
            winner[:points] += 1;
            if (winner[:points] == 4 && loser[:points] < 3) {
                // Reached 40 with opponent not at 40 — win the game
                winGame(winner, loser);
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // winGame(winner, loser)
    // Awards a game and resets points to zero.
    // Then checks if the set is won.
    // ─────────────────────────────────────────────────────────
    function winGame(winner, loser) {
        winner[:games] += 1;
        winner[:points] = 0;
        loser[:points]  = 0;
        inTiebreak = false; // tiebreak ends when game is won
        checkSetWin(winner, loser);
    }

    // ─────────────────────────────────────────────────────────
    // checkSetWin(winner, loser)
    // Called after every game. Determines if the set is over.
    // ─────────────────────────────────────────────────────────
    function checkSetWin(winner, loser) {
        var wg = winner[:games];
        var lg = loser[:games];

        // ── Super tiebreak replaces final set? ──────────────
        // Triggered when both players have won (setsToWin - 1) sets
        // and the score reaches 0-0 in what would be the final set.
        var totalSets = player[:sets] + opponent[:sets];
        if (superTiebreakFinalSet && totalSets == (setsToWin * 2 - 2)) {
            // This is the final set — use super tiebreak instead
            // It starts at 0-0 in games, trigger immediately
            if (wg == 1 && lg == 0) {
                // First game of the final set just won — start super tiebreak
                inSuperTiebreak = true;
                winner[:games]  = 0; // reset, super tiebreak uses points only
                winner[:points] = 1; // that game counts as point 1
                return;
            }
        }

        // ── Normal tiebreak at 6-6? ──────────────────────────
        if (tiebreakEnabled && wg == 6 && lg == 6) {
            inTiebreak = true;
            return;
        }

        // ── Standard set win: ≥6 games, lead by ≥2 ──────────
        if (wg >= 6 && (wg - lg) >= 2) {
            winner[:sets] += 1;
            resetAfterSet();
            checkMatchWin(winner);
        }
    }

    // ─────────────────────────────────────────────────────────
    // checkTiebreakWin(winner, loser)
    // Regular tiebreak: first to 7 points, must lead by 2.
    // ─────────────────────────────────────────────────────────
    function checkTiebreakWin(winner, loser) {
        var wp = winner[:points];
        var lp = loser[:points];

        if (wp >= 7 && (wp - lp) >= 2) {
            inTiebreak = false;
            winner[:sets] += 1;
            resetAfterSet();
            checkMatchWin(winner);
        }
    }

    // ─────────────────────────────────────────────────────────
    // checkSuperTiebreakWin(winner, loser)
    // Super tiebreak (match tiebreak): first to 10 points, lead by 2.
    // ─────────────────────────────────────────────────────────
    function checkSuperTiebreakWin(winner, loser) {
        var wp = winner[:points];
        var lp = loser[:points];

        if (wp >= 10 && (wp - lp) >= 2) {
            inSuperTiebreak = false;
            winner[:sets] += 1;
            resetAfterSet();
            checkMatchWin(winner);
        }
    }

    // ─────────────────────────────────────────────────────────
    // resetAfterSet()
    // Clears games and points for both players after a set ends.
    // ─────────────────────────────────────────────────────────
    function resetAfterSet() {
        player[:games]   = 0;
        player[:points]  = 0;
        opponent[:games] = 0;
        opponent[:points] = 0;
    }

    // ─────────────────────────────────────────────────────────
    // checkMatchWin(winner)
    // Called after each set. Checks if someone has won the match.
    // ─────────────────────────────────────────────────────────
    function checkMatchWin(winner) {
        if (winner[:sets] >= setsToWin) {
            matchOver = true;
        }
    }

    // ─────────────────────────────────────────────────────────
    // undo()
    // Reverts the last point by popping from the history stack.
    // Called when the user long-presses the screen.
    // ─────────────────────────────────────────────────────────
    function undo() {
        if (history.size() > 0) {
            var prev = history.remove(history.size() - 1);
            player          = prev[:player];
            opponent        = prev[:opponent];
            inTiebreak      = prev[:inTiebreak];
            inSuperTiebreak = prev[:inSuperTiebreak];
            matchOver       = prev[:matchOver];
        }
    }

    // ─────────────────────────────────────────────────────────
    // saveState()
    // Takes a snapshot of the current state and pushes it to history.
    // Called automatically before every input.
    // ─────────────────────────────────────────────────────────
    function saveState() {
        history.add({
            :player          => clonePlayer(player),
            :opponent        => clonePlayer(opponent),
            :inTiebreak      => inTiebreak,
            :inSuperTiebreak => inSuperTiebreak,
            :matchOver       => matchOver
        });

        // Keep history bounded to avoid running out of watch memory
        if (history.size() > 50) {
            history.remove(0);
        }
    }

    // ─────────────────────────────────────────────────────────
    // clonePlayer(p)
    // Creates a deep copy of a player dictionary.
    // Needed because Monkey C dictionaries are passed by reference.
    // ─────────────────────────────────────────────────────────
    function clonePlayer(p) {
        return {
            :points         => p[:points],
            :games          => p[:games],
            :sets           => p[:sets],
            :winners        => p[:winners],
            :unforcedErrors => p[:unforcedErrors],
            :doubleFaults   => p[:doubleFaults]
        };
    }

    // ─────────────────────────────────────────────────────────
    // getPointDisplay(p)
    // Returns the display string for a player's current points.
    // In tiebreaks, the raw number is shown (0, 1, 2, 3...).
    // In normal play: 0→"0", 1→"15", 2→"30", 3→"40", 4→"Ad"
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
    // Returns how many seconds have passed since match start.
    // System.getTimer() returns milliseconds since device boot.
    // ─────────────────────────────────────────────────────────
    function getElapsedSeconds() {
        return (Sys.getTimer() - startTime) / 1000;
    }

    // ─────────────────────────────────────────────────────────
    // getState()
    // Returns a serializable dictionary of the full match state.
    // Used by MatchPersistence to save to Toybox.Storage.
    // ─────────────────────────────────────────────────────────
    function getState() {
        return {
            :player          => clonePlayer(player),
            :opponent        => clonePlayer(opponent),
            :inTiebreak      => inTiebreak,
            :inSuperTiebreak => inSuperTiebreak,
            :matchOver       => matchOver,
            :setsToWin       => setsToWin,
            :tiebreakEnabled => tiebreakEnabled,
            :superTiebreakFinalSet => superTiebreakFinalSet,
            :startTime       => startTime
        };
    }

    // ─────────────────────────────────────────────────────────
    // restore(state)
    // Rebuilds the engine from a saved state dictionary.
    // Used by MatchPersistence when resuming a match.
    // ─────────────────────────────────────────────────────────
    function restore(state) {
        player                = state[:player];
        opponent              = state[:opponent];
        inTiebreak            = state[:inTiebreak];
        inSuperTiebreak       = state[:inSuperTiebreak];
        matchOver             = state[:matchOver];
        setsToWin             = state[:setsToWin];
        tiebreakEnabled       = state[:tiebreakEnabled];
        superTiebreakFinalSet = state[:superTiebreakFinalSet];
        startTime             = state[:startTime];
        history               = []; // History is not persisted — start fresh
    }
}
