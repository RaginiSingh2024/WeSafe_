// WeSafe - Firebase Cloud Messaging Service Worker
// This file MUST be at the root of the /web folder so Chrome can register it.
// It enables background push notifications when the app tab is not active.

importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// ── IMPORTANT ──────────────────────────────────────────────────────────────
// Replace the values below with your own Firebase project config.
// Find them in: Firebase Console → Project Settings → General → Your apps
// ───────────────────────────────────────────────────────────────────────────
firebase.initializeApp({
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT_ID.appspot.com",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID",
});

const messaging = firebase.messaging();

// Handle background push messages
messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message:", payload);

  const notificationTitle = payload.notification?.title || "🚨 WeSafe SOS Alert!";
  const notificationOptions = {
    body: payload.notification?.body || "An emergency alert was triggered.",
    icon: "/icons/Icon-192.png",   // WeSafe app icon shown in the notification
    badge: "/icons/Icon-192.png",
    tag: "wesafe-sos",             // Replaces existing notification instead of stacking
    requireInteraction: true,      // Keeps notification visible until user acts
    data: payload.data,
    actions: [
      { action: "view", title: "Open WeSafe" },
    ],
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click → focus or open the WeSafe tab
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && "focus" in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow("/");
      }
    })
  );
});

The above content shows the entire, complete file contents of the requested file.
