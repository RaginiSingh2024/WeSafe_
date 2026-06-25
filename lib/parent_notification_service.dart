import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womensafteyhackfair/cloud_service.dart';

/// ParentNotificationService — handles the parent/guardian alert system.
/// When a user triggers SOS, this service:
///   1. Looks up all guardians for this user
///   2. Queues FCM push notifications for each guardian
///   3. Records the notification in Firestore for audit
class ParentNotificationService {
  static final ParentNotificationService _instance =
      ParentNotificationService._internal();
  factory ParentNotificationService() => _instance;
  ParentNotificationService._internal();

  final _cloudService = CloudService();

  /// Main entry point — call this whenever any SOS fires.
  Future<void> alertAllGuardians({
    required String alertId,
    required String mapLink,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('registered_email') ?? '';
      final userName = prefs.getString('registered_username') ?? 'WeSafe User';

      if (userEmail.isEmpty) {
        debugPrint('⚠️ No logged-in email — skipping guardian notifications');
        return;
      }

      final alertMessage =
          '🚨 $userName has triggered an SOS alert! Tap to see their live location: $mapLink';

      // Fetch all registered guardians for this user
      final guardians = await _cloudService.getGuardians(userEmail);

      for (final guardian in guardians) {
        final guardianEmail = guardian['guardian_email'] as String? ?? '';
        if (guardianEmail.isEmpty) continue;

        try {
          await FirebaseFirestore.instance.collection('notification_queue').add({
            'targetEmail': guardianEmail,
            'title': '🚨 WeSafe SOS Alert! ($userName)',
            'body': alertMessage,
            'senderName': userName,
            'alertId': alertId,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
          debugPrint('✅ Guardian notification queued for: $guardianEmail');
        } catch (e) {
          debugPrint('❌ Error queuing notification for $guardianEmail: $e');
        }
      }

      debugPrint('✅ Guardian alert dispatched for alertId: $alertId');
    } catch (e) {
      debugPrint('❌ ParentNotificationService error: $e');
    }
  }

  /// Register the current user as a guardian for another user.
  Future<bool> registerAsGuardian({
    required String protectedUserEmail,
    required String guardianName,
    required String guardianPhone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final myEmail = prefs.getString('registered_email') ?? '';
      if (myEmail.isEmpty) return false;

      await _cloudService.addGuardianLink(
        userEmail: protectedUserEmail,
        guardianEmail: myEmail,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error registering as guardian: $e');
      return false;
    }
  }

  /// Stream of live SOS alerts — used on the parent monitoring screen.
  Stream<QuerySnapshot> streamActiveAlerts() {
    return _cloudService.streamActiveAlerts();
  }

  /// Get SOS history for auditing.
  Future<List<Map<String, dynamic>>> getAlertHistory(String phone) =>
      _cloudService.getAlertHistory(phone);
}
