// ============================================================
// SyncStatus.mc — visible Supabase upload status (v1.4.7)
// MatchMind Tennis Tracker for Garmin Vivoactive 6
// ============================================================
// Failed uploads were previously only logged via Sys.println,
// which is invisible on the real watch. This module holds a
// short status string that PostMatchView and SetupView render,
// so we can finally see on-wrist what the HTTP layer is doing.
//
// Lifecycle of the string:
//   ""           — nothing attempted yet (views draw nothing)
//   "SYNC ..."   — uploadMatch() entered, building request
//   "SYNC SENT"  — makeWebRequest() call returned without throwing;
//                  waiting for onResponse()
//   "SYNC EXC"   — makeWebRequest() threw an exception (serializer
//                  or argument problem — request never left watch)
//   "SYNC OK"    — onResponse() got 200/201/204
//   "SYNC ERR n" — onResponse() got HTTP/CIQ error code n
//                  (negative n = CIQ transport error, e.g. -104 =
//                  no phone connection; positive = server reply)
// ============================================================

using Toybox.WatchUi as Ui;

module SyncStatus {

    var text = "";

    function set(s) {
        text = s;
        // Repaint whichever view is currently visible so the new
        // status shows immediately (safe to call outside a view).
        Ui.requestUpdate();
    }
}
