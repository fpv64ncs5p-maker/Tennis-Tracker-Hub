// ============================================================
// TennisActivityManager.mc — Garmin Connect Activity Integration
// Garmin Tennis Tracker for Vivoactive 6
// ============================================================
// This module handles:
//   - Starting/stopping a Garmin "SPORT_TENNIS" activity
//   - Pushing live metrics (winners, errors, double faults)
//   - Syncing heart rate, steps, distance from Toybox.Sensors
//   - Saving a FIT file that shows up in Garmin Connect
//
// IMPORTANT: Toybox.Activities requires the app manifest to declare
// the "fit" permission. Add this to your manifest.xml:
//   <uses-permission id="fit"/>
//   <uses-permission id="sensor_heart_rate"/>
// ============================================================

using Toybox.ActivityRecording as Rec;
using Toybox.FitContributor as Fit;
using Toybox.Sensor as Sensor;
using Toybox.Activity as Activity;

class TennisActivityManager {

    // The active recording session (Garmin Connect activity)
    var session;

    // FIT data fields — custom metrics pushed to Garmin Connect
    var winnersField;
    var errorsField;
    var doubleFaultsField;

    // FIT field IDs — these are arbitrary unique integers (1–255).
    // They identify custom data fields in the FIT file.
    const FIELD_WINNERS       = 1;
    const FIELD_ERRORS        = 2;
    const FIELD_DOUBLE_FAULTS = 3;

    // ─────────────────────────────────────────────────────────
    // initialize()
    // Sets up the object but does NOT start recording yet.
    // Call startSession() when the match actually begins.
    // ─────────────────────────────────────────────────────────
    function initialize() {
        session           = null;
        winnersField      = null;
        errorsField       = null;
        doubleFaultsField = null;
    }

    // ─────────────────────────────────────────────────────────
    // startSession()
    // Creates and starts a Garmin Connect tennis activity.
    // Call this when the player taps START in SetupView.
    // ─────────────────────────────────────────────────────────
    function startSession() {
        // Check Toybox.ActivityRecording is available on this device
        if (!Rec has :createSession) { return; }

        // Create a new recording session of type SPORT_TENNIS
        session = Rec.createSession({
            :name    => "Tennis Match",
            :sport   => Rec.SPORT_TENNIS,
            :subSport => Rec.SUB_SPORT_GENERIC
        });

        // Add custom FIT data fields (these appear in Garmin Connect)
        if (session != null && Fit has :createField) {
            winnersField = session.createField(
                "winners",
                FIELD_WINNERS,
                Fit.DATA_TYPE_UINT16,
                {:mesgType => Fit.MESG_TYPE_RECORD, :units => "pts"}
            );
            errorsField = session.createField(
                "errors",
                FIELD_ERRORS,
                Fit.DATA_TYPE_UINT16,
                {:mesgType => Fit.MESG_TYPE_RECORD, :units => "pts"}
            );
            doubleFaultsField = session.createField(
                "double_faults",
                FIELD_DOUBLE_FAULTS,
                Fit.DATA_TYPE_UINT16,
                {:mesgType => Fit.MESG_TYPE_RECORD, :units => "pts"}
            );
        }

        // Enable heart rate sensor
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Sensor.enableSensorEvents(method(:onSensorData));

        // Start the session — Garmin now records GPS + HR + metrics
        if (session != null) {
            session.start();
        }
    }

    // ─────────────────────────────────────────────────────────
    // updateMetrics(engine)
    // Call this after every point to push current stats to FIT.
    // Pass the TennisMatchEngine so we can read its stats.
    // ─────────────────────────────────────────────────────────
    function updateMetrics(engine) {
        if (session == null || !session.isRecording()) { return; }

        if (winnersField != null) {
            winnersField.setData(engine.player[:winners]);
        }
        if (errorsField != null) {
            errorsField.setData(engine.player[:unforcedErrors]);
        }
        if (doubleFaultsField != null) {
            doubleFaultsField.setData(engine.player[:doubleFaults]);
        }
    }

    // ─────────────────────────────────────────────────────────
    // onSensorData(sensorInfo)
    // Callback triggered by the heart rate sensor.
    // Garmin automatically logs HR to the FIT file.
    // ─────────────────────────────────────────────────────────
    function onSensorData(sensorInfo) {
        // sensorInfo.heartRate is auto-logged by the session.
        // No extra action needed — this is just a hook if you
        // want to display or process HR data in your UI.
    }

    // ─────────────────────────────────────────────────────────
    // getHeartRate()
    // Returns the current heart rate reading (or null if unavailable).
    // ─────────────────────────────────────────────────────────
    function getHeartRate() {
        var info = Activity.getActivityInfo();
        if (info != null && info has :currentHeartRate) {
            return info.currentHeartRate;
        }
        return null;
    }

    // ─────────────────────────────────────────────────────────
    // getSteps()
    // Returns total steps recorded during the session.
    // ─────────────────────────────────────────────────────────
    function getSteps() {
        var info = Activity.getActivityInfo();
        if (info != null && info has :steps) {
            return info.steps;
        }
        return 0;
    }

    // ─────────────────────────────────────────────────────────
    // stopSession()
    // Ends and saves the Garmin activity.
    // Call this when the match finishes.
    // The FIT file is then synced to Garmin Connect on next sync.
    // ─────────────────────────────────────────────────────────
    function stopSession() {
        if (session != null && session.isRecording()) {
            session.stop();
            session.save();
        }

        // Disable sensors
        Sensor.setEnabledSensors([]);
        Sensor.enableSensorEvents(null);

        session = null;
    }

    // ─────────────────────────────────────────────────────────
    // isActive()
    // Returns true if a session is currently recording.
    // ─────────────────────────────────────────────────────────
    function isActive() {
        return (session != null && session.isRecording());
    }
}
