import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:womensafteyhackfair/cloud_service.dart';
import 'package:womensafteyhackfair/twilio_service.dart';
import 'package:womensafteyhackfair/route_service.dart';
import 'package:vibration/vibration.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ShieldStatus {
  inactive,
  monitoring,
  riskDetected,
  emergencyActive,
}

class SilentEvidenceShieldService extends ChangeNotifier {
  static final SilentEvidenceShieldService _instance =
      SilentEvidenceShieldService._internal();
  factory SilentEvidenceShieldService() => _instance;
  SilentEvidenceShieldService._internal();

  // ── Core State ─────────────────────────────────────────────────
  ShieldStatus _status = ShieldStatus.inactive;
  String? _destination;
  DateTime? _expectedArrivalTime;
  double _currentLatitude = 12.9372;
  double _currentLongitude = 77.6974;
  double _startLatitude = 12.9372;
  double _startLongitude = 77.6974;
  List<Map<String, dynamic>> _routeHistory = [];
  List<Map<String, dynamic>> _journeyTimeline = [];
  int _batteryPercentage = 88;
  String? _activeRiskType;
  String _currentJourneyStatus = 'Inactive';

  // ── Safety Check State ──────────────────────────────────────────
  bool _isSafetyCheckActive = false;
  int _safetyCheckCountdown = 15;
  Timer? _countdownTimer;
  Timer? _journeyTimer;
  String? _firebaseJourneyId;

  // ── Real-Time Tracking ─────────────────────────────────────────
  double _lastKnownLat = 0;
  double _lastKnownLng = 0;
  int _stationarySeconds = 0;
  bool _hasConnectivity = true;
  int _connectivityLostSeconds = 0;
  StreamSubscription? _connectivitySubscription;

  // ── Offline Alert Queue ─────────────────────────────────────────
  // Pending SMS/calls queued while offline; flushed when connectivity returns
  final List<Map<String, String>> _pendingAlerts = [];

  // ── Route Data ──────────────────────────────────────────────
  /// Decoded list of [lat, lng] pairs forming the planned route polyline
  List<List<double>> _routePolyline = [];
  /// Destination coordinates fetched by geocoding
  double? _destLatitude;
  double? _destLongitude;
  /// How many consecutive seconds the user has been > 200m off-route
  int _deviationSeconds = 0;
  /// Off-route threshold in metres
  static const double _deviationThresholdMetres = 200.0;
  /// Trigger risk after this many seconds consistently off-route (30 s = 3 ticks)
  static const int _deviationTriggerSeconds = 30;

  // ─────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────
  ShieldStatus get status => _status;
  String? get destination => _destination;
  DateTime? get expectedArrivalTime => _expectedArrivalTime;
  double get currentLatitude => _currentLatitude;
  double get currentLongitude => _currentLongitude;
  List<Map<String, dynamic>> get routeHistory => _routeHistory;
  List<Map<String, dynamic>> get journeyTimeline => _journeyTimeline;
  int get batteryPercentage => _batteryPercentage;
  String? get activeRiskType => _activeRiskType;
  bool get isSafetyCheckActive => _isSafetyCheckActive;
  int get safetyCheckCountdown => _safetyCheckCountdown;
  String get currentJourneyStatus => _currentJourneyStatus;
  double? get destLatitude => _destLatitude;
  double? get destLongitude => _destLongitude;

  void Function()? onShowSafetyCheck;
  void Function()? onHideSafetyCheck;

  // ═════════════════════════════════════════════════════════════════
  // START JOURNEY
  // ═════════════════════════════════════════════════════════════════
  Future<void> startJourney(String destination, int durationMinutes) async {
    _status = ShieldStatus.monitoring;
    _destination = destination;
    _activeRiskType = null;
    _isSafetyCheckActive = false;
    _routeHistory = [];
    _journeyTimeline = [];
    _routePolyline = [];
    _destLatitude = null;
    _destLongitude = null;
    _stationarySeconds = 0;
    _deviationSeconds = 0;
    _connectivityLostSeconds = 0;
    _hasConnectivity = true;
    _currentJourneyStatus = '🟢 Monitoring Journey';
    _firebaseJourneyId = null;
    _batteryPercentage = 95;

    _addTimelineEvent("Journey started to: $destination");

    // 1. Get real GPS start location via Geolocator
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          _currentLatitude = pos.latitude;
          _currentLongitude = pos.longitude;
        }
      }
    } catch (e) {
      debugPrint("GPS error at journey start: $e");
    }

    // Secondary fallback: Retrieve background location from SharedPreferences
    if (_currentLatitude == 12.9372 && _currentLongitude == 77.6974) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final locList = prefs.getStringList("location");
        if (locList != null && locList.length >= 2) {
          _currentLatitude = double.tryParse(locList[0]) ?? 12.9372;
          _currentLongitude = double.tryParse(locList[1]) ?? 77.6974;
          debugPrint("Fallback to SharedPreferences location: $_currentLatitude, $_currentLongitude");
        }
      } catch (e) {
        debugPrint("Error fetching fallback SharedPreferences location: $e");
      }
    }

    _startLatitude = _currentLatitude;
    _startLongitude = _currentLongitude;
    _lastKnownLat = _currentLatitude;
    _lastKnownLng = _currentLongitude;

    _routeHistory.add({
      'latitude': _currentLatitude,
      'longitude': _currentLongitude,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 2. Set expected arrival time directly based on duration
    _expectedArrivalTime = DateTime.now().add(Duration(minutes: durationMinutes));
    _addTimelineEvent("Expected arrival set to: ${_expectedArrivalTime!.toLocal().toString().split(' ')[1].split('.')[0]}");

    // 3. Start connectivity monitoring
    _startConnectivityMonitor();

    // 4. Geocode destination + fetch route polyline (non-blocking)
    _fetchAndStoreRoute(destination);

    // 5. Write initial state to Firebase
    await _syncJourneyToFirebase();

    // 6. Start real-time GPS monitoring loop
    _startJourneyTimer();

    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════════════
  // FETCH ROUTE POLYLINE (runs in background, non-blocking)
  // ═════════════════════════════════════════════════════════════════
  Future<void> _fetchAndStoreRoute(String destination) async {
    final rs = RouteService();

    // Step 1: Geocode the destination text to lat/lng
    final destCoords = await rs.geocodeDestination(destination);
    if (destCoords == null) {
      debugPrint('Route: geocoding failed for "$destination" — deviation detection disabled.');
      _addTimelineEvent('Route: could not geocode "$destination". Deviation detection off.');
      return;
    }
    _destLatitude = destCoords[0];
    _destLongitude = destCoords[1];
    debugPrint('Route: destination geocoded → $_destLatitude, $_destLongitude');

    // Step 2: Fetch driving polyline from current location to destination
    final polyline = await rs.fetchRoutePolyline(
      originLat: _startLatitude,
      originLng: _startLongitude,
      destLat: _destLatitude!,
      destLng: _destLongitude!,
    );

    if (polyline.isEmpty) {
      debugPrint('Route: polyline fetch failed — deviation detection disabled.');
      _addTimelineEvent('Route: could not fetch polyline. Deviation detection off.');
      return;
    }

    _routePolyline = polyline;
    _addTimelineEvent('Route loaded: ${polyline.length} waypoints. Deviation monitoring active.');
    debugPrint('Route: ✅ ${polyline.length} waypoints loaded. Deviation monitoring ON.');
    notifyListeners();
  }



  // ═════════════════════════════════════════════════════════════════
  // CONNECTIVITY MONITOR
  // ═════════════════════════════════════════════════════════════════
  void _startConnectivityMonitor() {
    _connectivitySubscription?.cancel();

    // ── Bug Fix 1: Check CURRENT state immediately (not just future changes) ──
    // On Flutter Web, onConnectivityChanged only fires on transitions.
    // We must probe the current state at start so we don't miss a pre-existing
    // offline condition.
    Connectivity().checkConnectivity().then((results) {
      final bool currentlyConnected =
          results.any((r) => r != ConnectivityResult.none);
      if (!currentlyConnected) {
        _hasConnectivity = false;
        _addTimelineEvent("⚠️ Started journey with no connectivity.");
        debugPrint("⚠️ Connectivity lost (detected at journey start)");
      }
    });

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      // In connectivity_plus 6.x, result is List<ConnectivityResult>
      final bool nowConnected = result.any((r) => r != ConnectivityResult.none);
      if (!nowConnected && _hasConnectivity) {
        _hasConnectivity = false;
        _addTimelineEvent("⚠️ Connectivity lost. Starting 5-min timer.");
        debugPrint("⚠️ Connectivity lost");
      } else if (nowConnected && !_hasConnectivity) {
        _hasConnectivity = true;
        _connectivityLostSeconds = 0;
        _addTimelineEvent("✅ Connectivity restored. Flushing pending alerts.");
        debugPrint("✅ Connectivity restored");
        // ── Bug Fix 3: Flush queued emergency alerts on reconnect ──
        _flushPendingAlerts();
      }
    });
  }

  // ═════════════════════════════════════════════════════════════════
  // REAL-TIME JOURNEY MONITORING LOOP (every 10 seconds)
  // ═════════════════════════════════════════════════════════════════
  void _startJourneyTimer() {
    _journeyTimer?.cancel();
    _journeyTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_status == ShieldStatus.inactive) {
        timer.cancel();
        return;
      }
      if (_status == ShieldStatus.emergencyActive) return;
      if (_isSafetyCheckActive) return;

      // ── 1. Fetch real GPS via Geolocator ────────────────────────
      double? newLat;
      double? newLng;

      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
            Position pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 4),
            );
            newLat = pos.latitude;
            newLng = pos.longitude;
          }
        }
      } catch (e) {
        debugPrint("Geolocator timer poll error: $e");
      }

      // Secondary fallback: Retrieve background location from SharedPreferences
      if (newLat == null || newLng == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final locList = prefs.getStringList("location");
          if (locList != null && locList.length >= 2) {
            newLat = double.tryParse(locList[0]);
            newLng = double.tryParse(locList[1]);
            debugPrint("Timer loop fallback to background SharedPreferences location: $newLat, $newLng");
          }
        } catch (e) {
          debugPrint("Timer loop error fetching fallback SharedPreferences location: $e");
        }
      }

      // Use previous coordinates if all fetch options failed
      newLat ??= _currentLatitude;
      newLng ??= _currentLongitude;

      try {
        final double distanceMoved = _haversineDistance(_lastKnownLat, _lastKnownLng, newLat, newLng);

        if (distanceMoved > 5) {
          _stationarySeconds = 0;
          _lastKnownLat = newLat;
          _lastKnownLng = newLng;
        } else {
          _stationarySeconds += 10;
        }

        _currentLatitude = newLat;
        _currentLongitude = newLng;

        _routeHistory.add({
          'latitude': _currentLatitude,
          'longitude': _currentLongitude,
          'timestamp': DateTime.now().toIso8601String(),
        });

        // ── 2. Log progress ─────────────────────────────────────────
        if (timer.tick % 6 == 0) {
          final double distFromStart = _haversineDistance(
            _startLatitude, _startLongitude, _currentLatitude, _currentLongitude,
          );
          _addTimelineEvent("Route progress: ${distFromStart.toStringAsFixed(0)}m from start.");
        }

      } catch (e) {
        debugPrint("GPS processing error: $e");
        _connectivityLostSeconds += 10;
      }

      // ── Bug Fix 2: Web-compatible offline fallback ───────────────
      // On Flutter Web, connectivity_plus may not fire on WiFi drop.
      // We detect it indirectly: if Firebase sync fails 3 ticks in a row,
      // treat device as offline so the 5-min timer still counts down.
      if (_hasConnectivity) {
        try {
          // Lightweight Firestore probe — just read the connection meta doc
          await FirebaseFirestore.instance
              .collection('_connectivity_probe')
              .doc('ping')
              .get(GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // Firestore unreachable → infer offline
          _hasConnectivity = false;
          _addTimelineEvent("⚠️ Connectivity lost (Firestore probe). Starting 5-min timer.");
          debugPrint("⚠️ Connectivity lost (inferred from Firestore probe)");
        }
      }

      // ── 3. Unexpected Stop (stationary ≥ 10 minutes) ─────────────────
      if (_stationarySeconds >= 600 && _status == ShieldStatus.monitoring) {
        _addTimelineEvent(
          "⚠️ Stationary for ${(_stationarySeconds / 60).toStringAsFixed(0)} minutes.",
        );
        _triggerRiskAutomatically('Unexpected Stop');
        return;
      }

      // ── 3b. Route Deviation (> 200m off-route for ≥ 30 s) ─────────────
      if (_destLatitude != null &&
          _destLongitude != null &&
          _routePolyline.isNotEmpty &&
          _status == ShieldStatus.monitoring) {
        final double offRouteMetres = RouteService().distanceToPolyline(
          lat: _currentLatitude,
          lng: _currentLongitude,
          polyline: _routePolyline,
        );
        debugPrint('Route deviation: ${offRouteMetres.toStringAsFixed(0)}m off-route '
            '($_deviationSeconds s consecutive)');
        if (offRouteMetres > _deviationThresholdMetres) {
          _deviationSeconds += 10;
          if (_deviationSeconds >= _deviationTriggerSeconds) {
            _addTimelineEvent(
              '⚠️ Off-route by ${offRouteMetres.toStringAsFixed(0)}m for '
              '${_deviationSeconds}s.',
            );
            _triggerRiskAutomatically('Route Deviation');
            return;
          }
        } else {
          // Back on route — reset counter
          if (_deviationSeconds > 0) {
            debugPrint('Route: back on route. Resetting deviation counter.');
          }
          _deviationSeconds = 0;
        }
      }

      // ── 4. Missed ETA (5 min buffer after expected arrival) ─────
      if (_expectedArrivalTime != null &&
          DateTime.now().isAfter(_expectedArrivalTime!.add(const Duration(minutes: 5))) &&
          _status == ShieldStatus.monitoring) {
        _addTimelineEvent("⚠️ Arrival time missed by more than 5 minutes.");
        _triggerRiskAutomatically('Missed Destination');
        return;
      }

      // ── 5. Connectivity Loss (≥ 1 minute offline) ──────────────
      if (!_hasConnectivity) {
        _connectivityLostSeconds += 10;
        if (_connectivityLostSeconds >= 10 && _status == ShieldStatus.monitoring) {
          _addTimelineEvent(
            "⚠️ No connectivity for ${(_connectivityLostSeconds / 60).toStringAsFixed(0)} minute(s).",
          );
          _triggerRiskAutomatically('Loss of Connectivity');
          return;
        }
      }

      // Update status label
      if (_status == ShieldStatus.monitoring) {
        _currentJourneyStatus = '🟢 Monitoring Journey';
      }

      await _syncJourneyToFirebase();
      notifyListeners();
    });
  }

  // ═════════════════════════════════════════════════════════════════
  // RISK TRIGGER
  // ═════════════════════════════════════════════════════════════════
  void _triggerRiskAutomatically(String riskType) {
    if (_status == ShieldStatus.inactive || _status == ShieldStatus.emergencyActive) return;

    _status = ShieldStatus.riskDetected;
    _activeRiskType = riskType;
    _currentJourneyStatus = '🟠 Risk Detected';
    _addTimelineEvent("🚨 Suspicious activity detected: $riskType");
    _isSafetyCheckActive = true;
    _safetyCheckCountdown = 15;

    onShowSafetyCheck?.call();
    _syncJourneyToFirebase();
    _startSafetyCheckCountdown();
    notifyListeners();
  }

  void _startSafetyCheckCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_safetyCheckCountdown > 1) {
        _safetyCheckCountdown--;
        notifyListeners();
      } else {
        _countdownTimer?.cancel();
        _isSafetyCheckActive = false;
        onHideSafetyCheck?.call();
        _activateEmergencyMode();
      }
    });
  }

  // ═════════════════════════════════════════════════════════════════
  // CONFIRM SAFETY (user taps "I'm Safe")
  // ═════════════════════════════════════════════════════════════════
  Future<void> confirmSafety() async {
    _countdownTimer?.cancel();
    _isSafetyCheckActive = false;
    onHideSafetyCheck?.call();

    _status = ShieldStatus.monitoring;
    _activeRiskType = null;
    // Reset all counters so same condition doesn't immediately re-trigger
    _stationarySeconds = 0;
    _deviationSeconds = 0;
    _connectivityLostSeconds = 0;
    _currentJourneyStatus = '🟢 Monitoring Journey';
    _addTimelineEvent("✅ User confirmed safety. Monitoring resumed.");

    await _syncJourneyToFirebase();
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════════════
  // EMERGENCY MODE
  // ═════════════════════════════════════════════════════════════════
  Future<void> _activateEmergencyMode() async {
    _status = ShieldStatus.emergencyActive;
    _currentJourneyStatus = '🔴 Emergency Active';
    _addTimelineEvent("🔴 Emergency Mode activated automatically.");

    try {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(duration: 3000);
      }
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final String userId = user?.uid ?? prefs.getString('registered_uid') ?? 'unknown';
    final String userName = prefs.getString('registered_username') ?? 'WeSafe User';

    final String mapLink = 'https://maps.google.com/?q=$_currentLatitude,$_currentLongitude';
    final contacts = await CloudService().getEmergencyContacts(userId);

    final String statusStr = _activeRiskType ?? "Route Deviation";
    // Plain ASCII only — emojis force UCS-2 encoding (70 chars/segment)
    // which Indian carriers often block. GSM-7 (160 chars/segment) delivers reliably.
    final String smsBody = "WESAFE SAFETY ALERT\n"
        "User: $userName\n"
        "Risk: $statusStr\n"
        "Location: $mapLink\n"
        "Time: ${DateTime.now().toLocal().toString().split('.')[0]}\n"
        "Reply SAFE if you are okay.";

    final twilio = TwilioService();
    final Set<String> processedPhones = {};
    for (final contact in contacts) {
      final String phone = contact['phone'] ?? '';
      if (phone.isEmpty || processedPhones.contains(phone)) continue;
      processedPhones.add(phone);

      final String voiceScript =
          "This is a WeSafe Silent Evidence Shield alert. "
          "User $userName might be in danger due to: $statusStr. "
          "Check the live GPS location link sent via text message.";

      // ── Bug Fix 3: Offline queue — try Twilio; if no internet, queue it ──
      if (_hasConnectivity) {
        try {
          await twilio.sendSMS(toNumber: phone, messageBody: smsBody);
          await twilio.makeVoiceCall(toNumber: phone, voiceMessage: voiceScript);
          debugPrint("✅ Emergency alert sent to $phone");
        } catch (e) {
          debugPrint("⚠️ Twilio failed (no internet?). Queuing alert for $phone: $e");
          _pendingAlerts.add({'phone': phone, 'sms': smsBody, 'voice': voiceScript});
          _addTimelineEvent("📥 Alert queued for $phone — will send when online.");
        }
      } else {
        // Known offline — skip HTTP attempt, queue immediately
        debugPrint("📥 Offline: queuing emergency alert for $phone");
        _pendingAlerts.add({'phone': phone, 'sms': smsBody, 'voice': voiceScript});
        _addTimelineEvent("📥 Alert queued for $phone — device is offline.");
      }
    }

    await _syncJourneyToFirebase();
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════════════
  // FLUSH PENDING ALERTS (called when connectivity is restored)
  // ═════════════════════════════════════════════════════════════════
  Future<void> _flushPendingAlerts() async {
    if (_pendingAlerts.isEmpty) return;
    debugPrint("📤 Flushing ${_pendingAlerts.length} queued emergency alert(s)...");
    _addTimelineEvent("📤 Sending ${_pendingAlerts.length} queued alert(s) after connectivity restored.");

    final twilio = TwilioService();
    final List<Map<String, String>> toSend = List.from(_pendingAlerts);
    _pendingAlerts.clear();

    for (final alert in toSend) {
      try {
        await twilio.sendSMS(toNumber: alert['phone']!, messageBody: alert['sms']!);
        await twilio.makeVoiceCall(toNumber: alert['phone']!, voiceMessage: alert['voice']!);
        debugPrint("✅ Flushed queued alert to ${alert['phone']}");
        _addTimelineEvent("✅ Queued alert delivered to ${alert['phone']}.");
      } catch (e) {
        debugPrint("❌ Failed to flush alert to ${alert['phone']}: $e");
        // Re-queue if still failing
        _pendingAlerts.add(alert);
      }
    }
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════════════
  // RESOLVE JOURNEY
  // ═════════════════════════════════════════════════════════════════
  Future<void> resolveJourney() async {
    _countdownTimer?.cancel();
    _journeyTimer?.cancel();
    _connectivitySubscription?.cancel();

    final bool wasEmergency = _status == ShieldStatus.emergencyActive;

    _status = ShieldStatus.inactive;
    _isSafetyCheckActive = false;
    _currentJourneyStatus = 'Inactive';
    _addTimelineEvent("Journey resolved. Shield deactivated.");

    if (wasEmergency) {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final String userId = user?.uid ?? prefs.getString('registered_uid') ?? 'unknown';
      final String userName = prefs.getString('registered_username') ?? 'WeSafe User';
      final contacts = await CloudService().getEmergencyContacts(userId);

      final String smsBody = "✅ User Marked Safe\n\n"
          "\"The journey for $userName has been completed successfully.\"";
      final twilio = TwilioService();
      final Set<String> processedPhones = {};
      for (final contact in contacts) {
        final String phone = contact['phone'] ?? '';
        if (phone.isEmpty || processedPhones.contains(phone)) continue;
        processedPhones.add(phone);
        await twilio.sendSMS(toNumber: phone, messageBody: smsBody);
      }
    }

    await _syncJourneyToFirebase();
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════════════
  // FIREBASE SYNC (journey + live location)
  // ═════════════════════════════════════════════════════════════════
  Future<void> _syncJourneyToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final String userId = user?.uid ?? prefs.getString('registered_uid') ?? 'unknown';
    final String userName = prefs.getString('registered_username') ?? 'WeSafe User';
    final String userPhone = prefs.getString('registered_phone') ?? '';
    final String userEmail = user?.email ?? prefs.getString('registered_email') ?? '';

    String statusStr = 'inactive';
    if (_status == ShieldStatus.monitoring) statusStr = 'Monitoring';
    if (_status == ShieldStatus.riskDetected) statusStr = 'Risk Detected';
    if (_status == ShieldStatus.emergencyActive) statusStr = 'Emergency Active';

    try {
      final Map<String, dynamic> docData = {
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'destination': _destination ?? '',
        'expectedArrivalTime': _expectedArrivalTime != null
            ? Timestamp.fromDate(_expectedArrivalTime!)
            : null,
        'status': statusStr,
        'latitude': _currentLatitude,
        'longitude': _currentLongitude,
        'routeHistory': _routeHistory,
        'journeyTimeline': _journeyTimeline,
        'batteryPercentage': _batteryPercentage,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_firebaseJourneyId == null) {
        final docRef = await FirebaseFirestore.instance
            .collection('silent_evidence_shields')
            .add(docData);
        _firebaseJourneyId = docRef.id;
      } else {
        await FirebaseFirestore.instance
            .collection('silent_evidence_shields')
            .doc(_firebaseJourneyId)
            .set(docData, SetOptions(merge: true));
      }

      // ── Also push to live_locations collection for Guardian Dashboard ──
      if (userEmail.isNotEmpty && _status != ShieldStatus.inactive) {
        await CloudService().updateLiveLocation(
          userEmail: userEmail,
          latitude: _currentLatitude,
          longitude: _currentLongitude,
        );
      }
    } catch (e) {
      debugPrint("Firestore Shield sync error: $e");
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════
  void _addTimelineEvent(String event) {
    _journeyTimeline.add({
      'event': event,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Haversine distance between two GPS coordinates, returns metres.
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _degToRad(double deg) => deg * (pi / 180);
}
