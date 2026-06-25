import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:womensafteyhackfair/constants.dart';

// Top-level function for handling background messages
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  // You can process background events here (e.g. log locally or update UI badge)
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> init() async {
    // 1. Set background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Received a foreground message: ${message.notification?.title}");

      // Show emergency toast to alert user immediately
      Fluttertoast.showToast(
        msg: "🚨 ${message.notification?.title ?? 'SOS Alert'}: ${message.notification?.body ?? 'Emergency triggered!'}",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: AppColors.primary,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    });

    // 3. Request permission (iOS)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Get & store FCM token
    final token = await _fcm.getToken();
    if (token != null) {
      debugPrint("FCM Token: $token");
    }
  }

  /// Get the current device FCM token.
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
      return null;
    }
  }

  /// Queue a push notification alert in Firestore for a target contact.
  /// A Cloud Function will pick this up and send the actual FCM push.
  Future<void> sendPushNotificationAlert({
    required String targetPhoneOrEmail,
    required String alertMessage,
    required String senderName,
  }) async {
    try {
      final cleanTarget = targetPhoneOrEmail.trim().toLowerCase();
      debugPrint("Searching FCM token for target contact: $cleanTarget");

      // Query target user in users collection either by email or phone
      QuerySnapshot querySnapshot;
      if (cleanTarget.contains('@')) {
        querySnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: cleanTarget)
            .limit(1)
            .get();
      } else {
        // Assume phone number search
        querySnapshot = await _firestore
            .collection('users')
            .where('phone', isEqualTo: cleanTarget)
            .limit(1)
            .get();
      }

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        final targetToken = data['fcmToken'] as String?;

        if (targetToken != null && targetToken.isNotEmpty) {
          // Write to notifications queue collection
          await _firestore.collection('notification_queue').add({
            'targetToken': targetToken,
            'title': "🚨 WeSafe SOS Alert! ($senderName)",
            'body': alertMessage,
            'senderName': senderName,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
          debugPrint("Push notification successfully queued in Firestore for target contact: $cleanTarget");
        } else {
          debugPrint("Target contact $cleanTarget has no active FCM Token registered.");
        }
      } else {
        debugPrint("Target contact $cleanTarget is not registered in the WeSafe cloud network.");
      }
    } catch (e) {
      debugPrint("Error queueing push notification: $e");
    }
  }
}
