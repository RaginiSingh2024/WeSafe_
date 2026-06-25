import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// CloudService — central Firestore interface for WeSafe
/// Handles: SOS alerts, live location, user accounts, parent/guardian contacts
class CloudService {
  static final CloudService _instance = CloudService._internal();
  factory CloudService() => _instance;
  CloudService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // SOS ALERTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a new SOS alert document and returns its Firestore ID.
  Future<String?> createSOSAlert({
    required String userName,
    required String phoneNumber,
    required String triggerKeyword,
    required double latitude,
    required double longitude,
    String triggerType = 'manual',           // 'manual' | 'voice' | 'wearable'
    List<String> notifiedContacts = const [],
  }) async {
    try {
      final docRef = await _firestore.collection('sos_alerts').add({
        'user_name': userName,
        'phone_number': phoneNumber,
        'trigger_keyword': triggerKeyword,
        'latitude': latitude,
        'longitude': longitude,
        'trigger_type': triggerType,
        'notified_contacts': notifiedContacts,
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
        'map_link':
            'https://maps.google.com/?q=$latitude,$longitude',
      });
      debugPrint('✅ SOS alert created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating SOS alert: $e');
      return null;
    }
  }

  /// Updates the status of an existing SOS alert (e.g., 'resolved').
  Future<void> updateSOSStatus(String alertId, String status) async {
    try {
      await _firestore.collection('sos_alerts').doc(alertId).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating SOS status: $e');
    }
  }

  /// Stream of active SOS alerts — used on monitoring screen.
  Stream<QuerySnapshot> streamActiveAlerts() {
    return _firestore
        .collection('sos_alerts')
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Get SOS history for a specific phone number.
  Future<List<Map<String, dynamic>>> getAlertHistory(String phone) async {
    try {
      final snap = await _firestore
          .collection('sos_alerts')
          .where('phone_number', isEqualTo: phone)
          .limit(50)
          .get();
      
      final docs = List<DocumentSnapshot>.from(snap.docs);
      docs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>? ?? {};
        final bData = b.data() as Map<String, dynamic>? ?? {};
        final aTime = aData['created_at'];
        final bTime = bData['created_at'];
        
        DateTime aDateTime;
        if (aTime is Timestamp) {
          aDateTime = aTime.toDate();
        } else if (aTime is int) {
          aDateTime = DateTime.fromMillisecondsSinceEpoch(aTime);
        } else {
          aDateTime = DateTime.fromMillisecondsSinceEpoch(0);
        }

        DateTime bDateTime;
        if (bTime is Timestamp) {
          bDateTime = bTime.toDate();
        } else if (bTime is int) {
          bDateTime = DateTime.fromMillisecondsSinceEpoch(bTime);
        } else {
          bDateTime = DateTime.fromMillisecondsSinceEpoch(0);
        }

        return bDateTime.compareTo(aDateTime);
      });

      return docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching alert history: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE LOCATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Push live location update for the user.
  Future<void> updateLiveLocation({
    required String userEmail,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    try {
      await _firestore
          .collection('live_locations')
          .doc(userEmail.toLowerCase())
          .set({
        'userId': userEmail.toLowerCase(),
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'timestamp': DateTime.now().toIso8601String(),
        'updated_at': FieldValue.serverTimestamp(),
        'map_link': 'https://maps.google.com/?q=$latitude,$longitude',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error updating live location: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER ACCOUNTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves or updates a user profile in Firestore.
  Future<void> saveUserProfile({
    required String email,
    required String name,
    required String phone,
    String? fcmToken,
  }) async {
    try {
      final data = <String, dynamic>{
        'email': email.toLowerCase(),
        'name': name,
        'phone': phone,
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (fcmToken != null) data['fcmToken'] = fcmToken;
      await _firestore
          .collection('users')
          .doc(email.toLowerCase())
          .set(data, SetOptions(merge: true));
      debugPrint('✅ User profile saved: $email');
    } catch (e) {
      debugPrint('❌ Error saving user profile: $e');
    }
  }

  /// Updates the FCM token for a registered user.
  Future<void> updateFcmToken(String email, String token) async {
    try {
      await _firestore.collection('users').doc(email.toLowerCase()).update({
        'fcmToken': token,
        'token_updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GUARDIAN / PARENT LINKS
  // ─────────────────────────────────────────────────────────────────────────

  /// Add a guardian link so a parent can monitor this user.
  Future<void> addGuardianLink({
    required String userEmail,
    required String guardianEmail,
    required String guardianName,
    required String guardianPhone,
  }) async {
    try {
      await _firestore
          .collection('guardian_links')
          .doc('${userEmail}_$guardianEmail')
          .set({
        'user_email': userEmail.toLowerCase(),
        'guardian_email': guardianEmail.toLowerCase(),
        'guardian_name': guardianName,
        'guardian_phone': guardianPhone,
        'linked_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Guardian link added: $guardianEmail → $userEmail');
    } catch (e) {
      debugPrint('❌ Error adding guardian link: $e');
    }
  }

  /// Fetch all guardians for a given user email.
  Future<List<Map<String, dynamic>>> getGuardians(String userEmail) async {
    try {
      final snap = await _firestore
          .collection('guardian_links')
          .where('user_email', isEqualTo: userEmail.toLowerCase())
          .get();
      return snap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching guardians: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WEARABLES
  // ─────────────────────────────────────────────────────────────────────────

  /// Save a wearable device to Firestore so guardians can see device status.
  Future<void> registerWearable({
    required String userEmail,
    required String deviceId,
    required String deviceName,
    required String deviceType, // 'watch' | 'pendant'
    int battery = 100,
  }) async {
    try {
      await _firestore
          .collection('wearables')
          .doc('${userEmail}_$deviceId')
          .set({
        'user_email': userEmail.toLowerCase(),
        'device_id': deviceId,
        'device_name': deviceName,
        'device_type': deviceType,
        'battery': battery,
        'is_connected': true,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Wearable registered: $deviceName ($deviceType)');
    } catch (e) {
      debugPrint('❌ Error registering wearable: $e');
    }
  }

  /// Update wearable battery / connection status.
  Future<void> updateWearableStatus({
    required String userEmail,
    required String deviceId,
    required bool isConnected,
    int? battery,
  }) async {
    try {
      final updates = <String, dynamic>{
        'is_connected': isConnected,
        'last_seen': FieldValue.serverTimestamp(),
      };
      if (battery != null) updates['battery'] = battery;
      await _firestore
          .collection('wearables')
          .doc('${userEmail}_$deviceId')
          .update(updates);
    } catch (e) {
      debugPrint('❌ Error updating wearable status: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMERGENCY CONTACTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Adds an emergency contact under the user's document sub-collection.
  Future<bool> addEmergencyContact(String userId, String name, String phone) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .add({
        'name': name,
        'phone': phone,
        'created_at': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Emergency contact added for user $userId: $name');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding emergency contact: $e');
      return false;
    }
  }

  /// Updates an emergency contact under the user's sub-collection.
  Future<bool> updateEmergencyContact(String userId, String contactId, String name, String phone) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .doc(contactId)
          .update({
        'name': name,
        'phone': phone,
        'updated_at': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Emergency contact updated: $contactId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating emergency contact: $e');
      return false;
    }
  }

  /// Deletes an emergency contact under the user's sub-collection.
  Future<bool> deleteEmergencyContact(String userId, String contactId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .doc(contactId)
          .delete();
      debugPrint('✅ Emergency contact deleted: $contactId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting emergency contact: $e');
      return false;
    }
  }

  /// Get real-time stream of emergency contacts for a given user.
  Stream<QuerySnapshot> streamEmergencyContacts(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('emergencyContacts')
        .orderBy('created_at', descending: false)
        .snapshots();
  }

  /// Fetch list of emergency contacts as a Future.
  Future<List<Map<String, dynamic>>> getEmergencyContacts(String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergencyContacts')
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching emergency contacts: $e');
      return [];
    }
  }

  /// Syncs connected devices status to Firestore for a user.
  Future<void> updateDeviceStatus(
    String userId, {
    required bool watchConnected,
    required bool pendantConnected,
    required String activeDevice,
  }) async {
    try {
      await _firestore.collection('devices').doc(userId).set({
        'watchConnected': watchConnected,
        'pendantConnected': pendantConnected,
        'activeDevice': activeDevice,
        'lastSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Synced device status to Firebase for user: $userId');
    } catch (e) {
      debugPrint('❌ Error syncing device status: $e');
    }
  }

  /// Fetch all users that this guardian is linked to monitor.
  Future<List<Map<String, dynamic>>> getMonitoredUsers(String guardianEmail) async {
    try {
      final snap = await _firestore
          .collection('guardian_links')
          .where('guardian_email', isEqualTo: guardianEmail.toLowerCase())
          .get();
      return snap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching monitored users: $e');
      return [];
    }
  }

  /// Streams active journeys from the Silent Evidence Shield.
  Stream<QuerySnapshot> streamActiveShieldJourneys() {
    return _firestore
        .collection('silent_evidence_shields')
        .where('status', whereIn: ['Monitoring', 'Risk Detected', 'Emergency Active'])
        .snapshots();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMMUNITY SAFETY NETWORK
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch all community groups the user has joined (by stored groupIds list).
  Future<List<Map<String, dynamic>>> getUserCommunityGroups(
      List<String> groupIds) async {
    if (groupIds.isEmpty) return [];
    try {
      final results = <Map<String, dynamic>>[];
      for (final id in groupIds) {
        final snap =
            await _firestore.collection('community_groups').doc(id).get();
        if (snap.exists) {
          final data = snap.data()!;
          data['id'] = snap.id;
          results.add(data);
        }
      }
      return results;
    } catch (e) {
      debugPrint('❌ Error fetching community groups: $e');
      return [];
    }
  }

  /// Stream of active emergency alerts in a given community group.
  Stream<QuerySnapshot> streamGroupEmergencyAlerts(String groupId) {
    return _firestore
        .collection('community_groups')
        .doc(groupId)
        .collection('messages')
        .where('type', isEqualTo: 'emergency')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots();
  }
}
