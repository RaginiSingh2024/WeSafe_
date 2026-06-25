import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CommunityChatService — manages community groups, real-time messages,
/// emergency alert broadcasts, and community response actions.
class CommunityChatService {
  static final CommunityChatService _instance = CommunityChatService._internal();
  factory CommunityChatService() => _instance;
  CommunityChatService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ───────────────────────────────────────────────────────────────────────────
  // GROUP MANAGEMENT
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns (or creates) a community group document for the given city/area.
  Future<String> getOrCreateGroup({
    required String city,
    String area = '',
  }) async {
    final groupName = area.isNotEmpty ? '$area Safety Network' : '$city Community Safety Chat';
    final groupKey = _toKey('${city}_$area');

    final docRef = _db.collection('community_groups').doc(groupKey);
    final snap = await docRef.get();

    if (!snap.exists) {
      final user = FirebaseAuth.instance.currentUser;
      await docRef.set({
        'id': groupKey,
        'name': groupName,
        'city': city,
        'area': area,
        'memberCount': 0,
        'created_at': FieldValue.serverTimestamp(),
        'hasActiveEmergency': false,
        'creatorId': user?.uid,
      });
      debugPrint('✅ Created community group: $groupName');
    }

    return groupKey;
  }

  /// Join a community group — adds the user to the members sub-collection.
  Future<void> joinGroup(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('registered_username') ?? 'WeSafe User';

    // 1. Add to group members sub-collection
    final memberRef = _db
        .collection('community_groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid);

    await memberRef.set({
      'userId': user.uid,
      'email': user.email ?? '',
      'name': userName,
      'joinedAt': FieldValue.serverTimestamp(),
      'isVerified': true,
    }, SetOptions(merge: true));

    // 2. Add to users/uid/joinedGroups field in users document
    await _db.collection('users').doc(user.uid).set({
      'joinedGroups': FieldValue.arrayUnion([groupId]),
    }, SetOptions(merge: true));

    // Increment member count
    await _db.collection('community_groups').doc(groupId).update({
      'memberCount': FieldValue.increment(1),
    });

    // Persist membership locally
    final joined = prefs.getStringList('joined_groups') ?? [];
    if (!joined.contains(groupId)) {
      joined.add(groupId);
      await prefs.setStringList('joined_groups', joined);
    }

    debugPrint('✅ Joined group: $groupId');
  }

  /// Leave a community group.
  Future<void> leaveGroup(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Remove from group members sub-collection
    await _db
        .collection('community_groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid)
        .delete();

    // 2. Remove from users/uid/joinedGroups field in users document
    await _db.collection('users').doc(user.uid).set({
      'joinedGroups': FieldValue.arrayRemove([groupId]),
    }, SetOptions(merge: true));

    await _db.collection('community_groups').doc(groupId).update({
      'memberCount': FieldValue.increment(-1),
    });

    final prefs = await SharedPreferences.getInstance();
    final joined = prefs.getStringList('joined_groups') ?? [];
    joined.remove(groupId);
    await prefs.setStringList('joined_groups', joined);

    debugPrint('✅ Left group: $groupId');
  }

  /// Delete a community group completely from Firestore.
  Future<void> deleteGroup(String groupId) async {
    try {
      // 1. Delete all messages inside the group
      final messagesRef = _db.collection('community_groups').doc(groupId).collection('messages');
      final messagesSnap = await messagesRef.get();
      for (final doc in messagesSnap.docs) {
        await doc.reference.delete();
      }

      // 2. Delete all member records inside the group
      final membersRef = _db.collection('community_groups').doc(groupId).collection('members');
      final membersSnap = await membersRef.get();
      for (final doc in membersSnap.docs) {
        final memberId = doc.id;
        await _db.collection('users').doc(memberId).set({
          'joinedGroups': FieldValue.arrayRemove([groupId])
        }, SetOptions(merge: true));
        await doc.reference.delete();
      }

      // 3. Delete the group document itself
      await _db.collection('community_groups').doc(groupId).delete();
      
      debugPrint('✅ Deleted group: $groupId');
    } catch (e) {
      debugPrint('❌ Error deleting group: $e');
    }
  }

  /// Check if current user is a member of a group.
  Future<bool> isMember(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final snap = await _db
        .collection('community_groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid)
        .get();
    return snap.exists;
  }

  /// Fetch all group IDs the current user has joined from Firestore.
  Future<List<String>> fetchJoinedGroupIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('joinedGroups')) {
          final List<dynamic> list = data['joinedGroups'] ?? [];
          return list.map((e) => e.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching joined group IDs: $e');
      return [];
    }
  }

  /// Stream of all available community groups (ordered by member count).
  Stream<QuerySnapshot> streamAllGroups() {
    return _db
        .collection('community_groups')
        .orderBy('memberCount', descending: true)
        .snapshots();
  }

  /// Stream groups the current user has joined.
  Stream<QuerySnapshot> streamUserGroups() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    // We stream all groups; the UI filters by local prefs membership
    return _db
        .collection('community_groups')
        .orderBy('hasActiveEmergency', descending: true)
        .snapshots();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MESSAGES
  // ───────────────────────────────────────────────────────────────────────────

  /// Real-time stream of messages for a group (newest 100).
  Stream<QuerySnapshot> streamMessages(String groupId) {
    return _db
        .collection('community_groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(100)
        .snapshots();
  }

  /// Send a plain text message.
  Future<void> sendMessage({
    required String groupId,
    required String content,
    bool anonymous = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userName = anonymous
        ? 'Anonymous WeSafe User'
        : (prefs.getString('registered_username') ?? 'WeSafe User');

    await _db
        .collection('community_groups')
        .doc(groupId)
        .collection('messages')
        .add({
      'senderId': anonymous ? 'anon_${user.uid.substring(0, 6)}' : user.uid,
      'senderName': userName,
      'isVerified': true,
      'isAnonymous': anonymous,
      'type': 'text',
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'isPinned': false,
      'responses': {
        'im_safe': 0,
        'going_to_help': 0,
        'notified_authorities': 0,
        'shared': 0,
      },
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // EMERGENCY BROADCAST
  // ───────────────────────────────────────────────────────────────────────────

  /// Called from Dashboard.triggerSOS() — broadcasts to all groups the user belongs to.
  Future<void> broadcastEmergencyToUserGroups({
    required String userId,
    required String userName,
    required double latitude,
    required double longitude,
    required String mapLink,
    required String triggerType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> joinedGroups = prefs.getStringList('joined_groups') ?? [];

      if (joinedGroups.isEmpty) {
        // Fallback to fetching directly from Firestore if local cache is empty
        joinedGroups = await fetchJoinedGroupIds();
        if (joinedGroups.isNotEmpty) {
          await prefs.setStringList('joined_groups', joinedGroups);
        }
      }

      if (joinedGroups.isEmpty) {
        debugPrint('⚠️ No community groups to broadcast to.');
        return;
      }

      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} · ${now.day}/${now.month}/${now.year}';

      for (final groupId in joinedGroups) {
        await _broadcastToGroup(
          groupId: groupId,
          userId: userId,
          userName: userName,
          latitude: latitude,
          longitude: longitude,
          mapLink: mapLink,
          triggerType: triggerType,
          timeStr: timeStr,
        );
      }

      debugPrint('🚨 Emergency broadcast sent to ${joinedGroups.length} group(s).');
    } catch (e) {
      debugPrint('❌ Error broadcasting emergency: $e');
    }
  }

  Future<void> _broadcastToGroup({
    required String groupId,
    required String userId,
    required String userName,
    required double latitude,
    required double longitude,
    required String mapLink,
    required String triggerType,
    required String timeStr,
  }) async {
    final alertContent = '🚨 EMERGENCY ALERT 🚨\n\n'
        'A user is in danger nearby.\n\n'
        'User: $userName\n'
        'Trigger: ${_formatTriggerType(triggerType)}\n\n'
        'Location: $mapLink\n\n'
        'Risk Level: HIGH\n\n'
        'Action Required:\n'
        '• Stay alert\n'
        '• Contact emergency services if possible\n'
        '• Do NOT ignore this alert\n\n'
        'Timestamp: $timeStr';

    // Add the emergency message to the group
    final msgRef = await _db
        .collection('community_groups')
        .doc(groupId)
        .collection('messages')
        .add({
      'senderId': userId,
      'senderName': userName,
      'isVerified': true,
      'isAnonymous': false,
      'type': 'emergency',
      'content': alertContent,
      'latitude': latitude,
      'longitude': longitude,
      'mapLink': mapLink,
      'riskLevel': 'HIGH',
      'triggerType': triggerType,
      'timestamp': FieldValue.serverTimestamp(),
      'isPinned': true,
      'responses': {
        'im_safe': 0,
        'going_to_help': 0,
        'notified_authorities': 0,
        'shared': 0,
      },
    });

    // Pin this alert at the group level
    await _db.collection('community_groups').doc(groupId).update({
      'hasActiveEmergency': true,
      'pinnedAlertId': msgRef.id,
      'pinnedAlertUserId': userId,
      'pinnedAlertUserName': userName,
      'pinnedAlertMapLink': mapLink,
      'pinnedAlertTimestamp': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ Emergency broadcast to group $groupId: ${msgRef.id}');
  }

  /// Clear the pinned emergency for a group (call when SOS resolved).
  Future<void> clearPinnedEmergency(String groupId) async {
    try {
      await _db.collection('community_groups').doc(groupId).update({
        'hasActiveEmergency': false,
        'pinnedAlertId': FieldValue.delete(),
        'pinnedAlertUserId': FieldValue.delete(),
        'pinnedAlertUserName': FieldValue.delete(),
        'pinnedAlertMapLink': FieldValue.delete(),
        'pinnedAlertTimestamp': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('❌ Error clearing pinned emergency: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // COMMUNITY RESPONSE BUTTONS
  // ───────────────────────────────────────────────────────────────────────────

  /// Increment a response counter on an emergency message.
  Future<void> addResponse({
    required String groupId,
    required String messageId,
    required String responseType, // 'im_safe' | 'going_to_help' | 'notified_authorities' | 'shared'
  }) async {
    try {
      await _db
          .collection('community_groups')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .update({
        'responses.$responseType': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('❌ Error adding response: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ───────────────────────────────────────────────────────────────────────────

  String _toKey(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  String _formatTriggerType(String type) {
    switch (type) {
      case 'manual':
        return 'Manual SOS';
      case 'voice':
        return 'Voice Detection';
      case 'shake_alert':
        return 'Shake Alert';
      case 'wearable':
        return 'Wearable Device';
      default:
        return type;
    }
  }

  /// Returns the current user's display name.
  Future<String> getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('registered_username') ?? 'WeSafe User';
  }

  /// Returns the current user's UID.
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
}
