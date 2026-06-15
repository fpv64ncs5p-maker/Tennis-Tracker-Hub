// ============================================================
// TennisActivityManager.mc — Activity & FIT Recording
// MatchMind Tennis Tracker for Garmin Vivoactive 6
// ============================================================
// v1.1.6: real-watch test of v1.1.5 showed Garmin Connect had NO
// "Connect IQ™" section at all (not even with zero values), proving
// the developer fields were never being written into the FIT file.
// Fix: seed every field with setData(0) immediately before
// _session.start(). createField() alone only registers the field
// *definition*; without an initial value, no field data is emitted.
//
// v1.1.5: redesigned FIT field schema so stats actually appear in
// Garmin Connect's "Connect IQ™" section. Lessons learned from a
// reference app (Daneel's "Tennis Tracker"):
//   • Field names must be human-readable strings ("Points won",
//     "Errors") — short codes like "p_pts" are filtered out.
//   • Fields must be SESSION-level (one value per match) or LAP-level
//     (one value per lap) — RECORD-level fields are silently dropped
//     by the Tennis activity template.
//   • Each completed SET writes a lap with per-set custom fields.
//
// SESSION fields (12, written at match end, displayed in Connect IQ™):
//   0  Points won
//   1  Errors
//   2  Double faults
//   3  Games won
//   4  Games lost
//   5  Sets won
//   6  Sets lost
//   7  Tiebreaks won
//   8  Tiebreak points won
//   9  Tiebreak points lost
//  10  Service points won
//  11  Return points won
//
// LAP fields (4, written at the end of each set, shown per lap row):
//  12  Set points won
//  13  Set errors
//  14  Set double faults
//  15  Set tiebreak       (0=none, 1=won by player, 2=lost by player)
// ============================================================

using Toybox.Activity as Activity;
using Toybox.ActivityRecording as Recording;
using Toybox.FitContributor as FitContributor;
using Toybox.Sensor as Sensor;
using Toybox.Application;

class TennisActivityManager {

    var isRunning;

    var _session;

    // v1.2: SupabaseSync instance held here so its callback method
    // reference stays alive while the HTTP request is in-flight.
    var _supabaseSync;

    // v1.3.6: guard so earlyUpload() only fires once per match
    // (protects against double-POST if the user somehow triggers it twice).
    var _uploadFired;

    // ── SESSION fields (match totals) ────────────────────────
    var _fPointsWon;
    var _fErrors;
    var _fDoubleFaults;
    var _fGamesWon;
    var _fGamesLost;
    var _fSetsWon;
    var _fSetsLost;
    var _fTiebreaksWon;
    var _fTBPointsWon;
    var _fTBPointsLost;
    var _fServicePointsWon;
    var _fReturnPointsWon;

    // ── LAP fields (per-set) ─────────────────────────────────
    var _fSetPointsWon;
    var _fSetErrors;
    var _fSetDoubleFaults;
    var _fSetTiebreak;

    function initialize() {
        isRunning           = false;
        _session            = null;
        _supabaseSync       = new SupabaseSync();
        _uploadFired        = false;
        _fPointsWon         = null;
        _fErrors            = null;
        _fDoubleFaults      = null;
        _fGamesWon          = null;
        _fGamesLost         = null;
        _fSetsWon           = null;
        _fSetsLost          = null;
        _fTiebreaksWon      = null;
        _fTBPointsWon       = null;
        _fTBPointsLost      = null;
        _fServicePointsWon  = null;
        _fReturnPointsWon   = null;
        _fSetPointsWon      = null;
        _fSetErrors         = null;
        _fSetDoubleFaults   = null;
        _fSetTiebreak       = null;
    }

    // ─────────────────────────────────────────────────────────
    // startSession()
    // ─────────────────────────────────────────────────────────
    function startSession() {
        if (Sensor has :setEnabledSensors) {
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        }

        if ((Toybox has :ActivityRecording) && (Recording has :createSession)) {
            // v1.1.9: reverted to SPORT_TENNIS. v1.1.7/1.1.8 tried
            // SPORT_GENERIC to bypass Garmin's Tennis-template filter on
            // developer fields, but real-watch testing with v1.1.8
            // proved Garmin Connect filters developer fields universally
            // (both web and mobile, regardless of sport type). So
            // SPORT_GENERIC gave up the tennis icon and Tennis Reports
            // aggregation for zero display gain. SPORT_TENNIS at least
            // restores those benefits. Stats are still in the FIT file
            // and visible in MatchMind's PostMatch screen; for external
            // visibility we'll sync to a Pocketbase backend (v1.2).
            _session = Recording.createSession({
                :name     => "Tennis Match",
                :sport    => Recording.SPORT_TENNIS,
                :subSport => Recording.SUB_SPORT_MATCH
            });

            // ── SESSION fields ────────────────────────────────
            var sessionOpts = { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => "" };
            var pointsOpts  = { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => "points" };

            _fPointsWon        = _session.createField("Points won",         0, FitContributor.DATA_TYPE_UINT16, pointsOpts);
            _fErrors           = _session.createField("Errors",             1, FitContributor.DATA_TYPE_UINT16, pointsOpts);
            _fDoubleFaults     = _session.createField("Double faults",      2, FitContributor.DATA_TYPE_UINT16, pointsOpts);
            _fGamesWon         = _session.createField("Games won",          3, FitContributor.DATA_TYPE_UINT16, sessionOpts);
            _fGamesLost        = _session.createField("Games lost",         4, FitContributor.DATA_TYPE_UINT16, sessionOpts);
            _fSetsWon          = _session.createField("Sets won",           5, FitContributor.DATA_TYPE_UINT8,  sessionOpts);
            _fSetsLost         = _session.createField("Sets lost",          6, FitContributor.DATA_TYPE_UINT8,  sessionOpts);
            _fTiebreaksWon     = _session.createField("Tiebreaks won",      7, FitContributor.DATA_TYPE_UINT8,  sessionOpts);
            _fTBPointsWon      = _session.createField("Tiebreak points won",  8, FitContributor.DATA_TYPE_UINT16, pointsOpts);
            _fTBPointsLost     = _session.createField("Tiebreak points lost", 9, FitContributor.DATA_TYPE_UINT16, pointsOpts);
            _fServicePointsWon = _session.createField("Service points won", 10, FitContributor.DATA_TYPE_UINT16, pointsOpts);
            _fReturnPointsWon  = _session.createField("Return points won",  11, FitContributor.DATA_TYPE_UINT16, pointsOpts);

            // ── LAP fields (one row per set in Garmin Connect) ─
            var lapOpts    = { :mesgType => FitContributor.MESG_TYPE_LAP, :units => "" };
            var lapPtsOpts = { :mesgType => FitContributor.MESG_TYPE_LAP, :units => "points" };

            _fSetPointsWon    = _session.createField("Set points won",    12, FitContributor.DATA_TYPE_UINT16, lapPtsOpts);
            _fSetErrors       = _session.createField("Set errors",        13, FitContributor.DATA_TYPE_UINT16, lapPtsOpts);
            _fSetDoubleFaults = _session.createField("Set double faults", 14, FitContributor.DATA_TYPE_UINT16, lapPtsOpts);
            _fSetTiebreak     = _session.createField("Set tiebreak",      15, FitContributor.DATA_TYPE_UINT8,  lapOpts);

            // ── v1.1.6: initialize every field with 0 BEFORE start() ──
            // Garmin's FitContributor only writes a developer field into the
            // FIT file if it has a value. createField() alone registers the
            // *definition* but not a value, so without this block the fields
            // never appear in Garmin Connect (no "Connect IQ™" section at all).
            // setData(0) seeds each field so subsequent writes show up.
            if (_fPointsWon         != null) { _fPointsWon.setData(0); }
            if (_fErrors            != null) { _fErrors.setData(0); }
            if (_fDoubleFaults      != null) { _fDoubleFaults.setData(0); }
            if (_fGamesWon          != null) { _fGamesWon.setData(0); }
            if (_fGamesLost         != null) { _fGamesLost.setData(0); }
            if (_fSetsWon           != null) { _fSetsWon.setData(0); }
            if (_fSetsLost          != null) { _fSetsLost.setData(0); }
            if (_fTiebreaksWon      != null) { _fTiebreaksWon.setData(0); }
            if (_fTBPointsWon       != null) { _fTBPointsWon.setData(0); }
            if (_fTBPointsLost      != null) { _fTBPointsLost.setData(0); }
            if (_fServicePointsWon  != null) { _fServicePointsWon.setData(0); }
            if (_fReturnPointsWon   != null) { _fReturnPointsWon.setData(0); }
            if (_fSetPointsWon      != null) { _fSetPointsWon.setData(0); }
            if (_fSetErrors         != null) { _fSetErrors.setData(0); }
            if (_fSetDoubleFaults   != null) { _fSetDoubleFaults.setData(0); }
            if (_fSetTiebreak       != null) { _fSetTiebreak.setData(0); }

            _session.start();
        }

        isRunning = true;
    }

    // ─────────────────────────────────────────────────────────
    // updateMetrics(engine)
    // No-op in v1.1.5: we no longer write per-second RECORD data.
    // SESSION + LAP fields are written at match-end / set-end only.
    // Kept for call-site compatibility.
    // ─────────────────────────────────────────────────────────
    function updateMetrics(engine) {
    }

    // ─────────────────────────────────────────────────────────
    // markSetEnd(engine)
    // v1.2.1: removed _session.addLap(). The Garmin OS announces
    // every lap out loud (beep + vibration), which is disruptive
    // mid-match. LAP-level custom fields are not displayed by Garmin
    // Connect anyway (developer fields are filtered server-side), so
    // nothing useful was lost. Per-set stats are still captured via
    // SESSION fields at match end. This method is kept as a no-op
    // so call sites in MainDelegate don't need to change.
    // ─────────────────────────────────────────────────────────
    function markSetEnd(engine) {
    }

    // ─────────────────────────────────────────────────────────
    // earlyUpload(engine)
    // v1.3.6: fires the Supabase POST the instant the last point is
    // scored, while the activity session is still live and Bluetooth
    // is still connected. This decouples the upload from stopSession()
    // and PostMatchView navigation entirely — so it survives even if
    // the Garmin OS intercepts the physical button and kills the app
    // before PostMatchView is ever shown.
    //
    // _uploadFired prevents a double-POST if stopSession() is also
    // called later (normal SAVE path). stopSession() checks the flag
    // and skips the redundant upload.
    // ─────────────────────────────────────────────────────────
    function earlyUpload(engine) {
        if (_uploadFired) { return; }
        if (engine != null && _supabaseSync != null) {
            _uploadFired = true;
            // v1.4.8: queue the payload (own slot) before firing so it
            // survives in Storage even if the app exits before
            // onResponse() — and can no longer be overwritten by the
            // next match. Cleared only on confirmed success.
            var slot = MatchPersistence.queueSupabasePayload(engine.getState());
            _supabaseSync.setSlot(slot);
            _supabaseSync.uploadMatch(engine, self);
            // v1.3.10: anchor self on TennisApp so GC cannot collect this
            // object (and the SupabaseSync callback within it) while the
            // async HTTP request is still in-flight.
            Application.getApp()._matchSync = self;
        }
    }

    // ─────────────────────────────────────────────────────────
    // stopSession(engine)
    // Writes the 12 SESSION-level summary fields, stops, and saves
    // the activity to Garmin Connect.
    // ─────────────────────────────────────────────────────────
    function stopSession(engine) {
        if (_session != null) {
            if (engine != null) {
                writeSessionFields(engine);
            }
            _session.stop();
            _session.save();
            _session = null;
        }
        if (Sensor has :setEnabledSensors) {
            Sensor.setEnabledSensors([]);
        }
        isRunning = false;

        // v1.2: push match data to Supabase (best-effort, async).
        // Only fires when stopSession is called (= match was SAVED).
        // discardSession() intentionally skips this.
        // v1.3.6: skip if earlyUpload() already fired the POST.
        // v1.3.8: save payload before firing so Storage survives app exit.
        if (engine != null && _supabaseSync != null && !_uploadFired) {
            _uploadFired = true;
            // v1.4.8: queued payload slot (see earlyUpload).
            var slot = MatchPersistence.queueSupabasePayload(engine.getState());
            _supabaseSync.setSlot(slot);
            _supabaseSync.uploadMatch(engine, self);
            // v1.3.10: anchor self on TennisApp against GC.
            Application.getApp()._matchSync = self;
        }
    }

    // ─────────────────────────────────────────────────────────
    // stopSessionForLater(engine)
    // v1.4.8: used by the LATER menu option. Stops and SAVES the
    // recording (partial activity in Garmin Connect) WITHOUT firing
    // the Supabase sync — the match isn't finished yet. Previously
    // LATER left the session running, so the watch OS showed its own
    // save dialog and "saved" matches bypassed MatchMind entirely.
    // ─────────────────────────────────────────────────────────
    function stopSessionForLater(engine) {
        if (_session != null) {
            if (engine != null) {
                writeSessionFields(engine);
            }
            _session.stop();
            _session.save();
            _session = null;
        }
        if (Sensor has :setEnabledSensors) {
            Sensor.setEnabledSensors([]);
        }
        isRunning = false;
    }

    function writeSessionFields(engine) {
        // Total games won/lost = sum across completed sets + current set
        var totalGamesP = engine.player[:games];
        var totalGamesO = engine.opponent[:games];
        if (engine.setHistory != null) {
            for (var i = 0; i < engine.setHistory.size(); i++) {
                var entry = engine.setHistory[i];
                totalGamesP += entry[:p];
                totalGamesO += entry[:o];
            }
        }

        if (_fPointsWon         != null) { _fPointsWon.setData(engine.player[:winners]); }
        if (_fErrors            != null) { _fErrors.setData(engine.player[:unforcedErrors]); }
        if (_fDoubleFaults      != null) { _fDoubleFaults.setData(engine.player[:doubleFaults]); }
        if (_fGamesWon          != null) { _fGamesWon.setData(totalGamesP); }
        if (_fGamesLost         != null) { _fGamesLost.setData(totalGamesO); }
        if (_fSetsWon           != null) { _fSetsWon.setData(engine.player[:sets]); }
        if (_fSetsLost          != null) { _fSetsLost.setData(engine.opponent[:sets]); }
        if (_fTiebreaksWon      != null) { _fTiebreaksWon.setData(engine.player[:tiebreaksWon]); }
        if (_fTBPointsWon       != null) { _fTBPointsWon.setData(engine.player[:tiebreakPointsWon]); }
        if (_fTBPointsLost      != null) { _fTBPointsLost.setData(engine.player[:tiebreakPointsLost]); }
        if (_fServicePointsWon  != null) { _fServicePointsWon.setData(engine.player[:servePtsWon]); }
        if (_fReturnPointsWon   != null) { _fReturnPointsWon.setData(engine.player[:returnPtsWon]); }
    }

    // ─────────────────────────────────────────────────────────
    // discardSession()
    // Stops the recording WITHOUT saving — used when the user
    // chooses DISCARD from the match menu.
    // ─────────────────────────────────────────────────────────
    function discardSession() {
        if (_session != null) {
            _session.stop();
            if (_session has :discard) {
                _session.discard();
            }
            _session = null;
        }
        if (Sensor has :setEnabledSensors) {
            Sensor.setEnabledSensors([]);
        }
        isRunning = false;
    }

    // ─────────────────────────────────────────────────────────
    // getHeartRate()
    // ─────────────────────────────────────────────────────────
    function getHeartRate() {
        var info = Activity.getActivityInfo();
        if (info != null && (info has :currentHeartRate)) {
            return info.currentHeartRate;
        }
        return null;
    }

    // ─────────────────────────────────────────────────────────
    // getSteps()
    // ─────────────────────────────────────────────────────────
    function getSteps() {
        var info = Activity.getActivityInfo();
        if (info != null && (info has :steps)) {
            return info.steps;
        }
        return 0;
    }

    function isActive() {
        return isRunning;
    }
}
