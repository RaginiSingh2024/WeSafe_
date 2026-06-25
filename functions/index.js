/**
 * WeSafe — Firebase Cloud Functions (Project: wesafe-5676c)
 *
 * Functions:
 *  1. dispatchFcmNotification  — sends FCM push for every pending notification_queue doc
 *  2. onSOSCreated             — auto-notifies guardians when a new SOS alert is created
 *  3. onSOSResolved            — sends "safe" push to guardians when SOS is resolved
 *  4. cleanupOldData           — daily cleanup of old notifications & resolved alerts
 *
 * Deploy: firebase deploy --only functions
 */

"use strict";

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();
const fcm = getMessaging();

// ─────────────────────────────────────────────────────────────────────────────
// 1. DISPATCH FCM NOTIFICATION
//    Triggered when any document is added to `notification_queue`.
//    Sends the push notification and marks the doc as sent/failed.
// ───────────────────────────────────────────────
<truncated 9191 bytes>
rName,
        type: "sos_resolved",
        timestamp: FieldValue.serverTimestamp(),
        status: "pending",
      });
    }
    await batch.commit();
    console.log(`✅ Sent 'safe' notifications for resolved alert: ${alertId}`);

    return null;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 4. DAILY CLEANUP — delete old notifications (>7 days) & resolved alerts (>30 days)
// ─────────────────────────────────────────────────────────────────────────────
exports.cleanupOldData = onSchedule("every 24 hours", async () => {
  const now = new Date();

  // Delete notification_queue docs older than 7 days
  const notifCutoff = new Date(now);
  notifCutoff.setDate(notifCutoff.getDate() - 7);

  const oldNotifs = await db
    .collection("notification_queue")
    .where("timestamp", "<", notifCutoff)
    .get();

  // Delete resolved alerts older than 30 days
  const alertCutoff = new Date(now);
  alertCutoff.setDate(alertCutoff.getDate() - 30);

  const oldAlerts = await db
    .collection("sos_alerts")
    .where("status", "==", "resolved")
    .where("resolved_at", "<", alertCutoff)
    .get();

  const batch = db.batch();
  oldNotifs.forEach((d) => batch.delete(d.ref));
  oldAlerts.forEach((d) => batch.delete(d.ref));
  await batch.commit();

  console.log(
    `🧹 Cleaned ${oldNotifs.size} old notifications, ${oldAlerts.size} old alerts`
  );
});

The above content shows the entire, complete file contents of the requested file.
