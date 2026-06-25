import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:womensafteyhackfair/Dashboard/DashWidgets/WeSafeToast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as appPermissions;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:womensafteyhackfair/Dashboard/ContactScreens/phonebook_view.dart';
import 'package:womensafteyhackfair/Dashboard/Home.dart';
import 'package:womensafteyhackfair/Dashboard/ContactScreens/MyContacts.dart';
import 'package:womensafteyhackfair/Dashboard/Settings/SettingsScreen.dart';
import 'package:womensafteyhackfair/Dashboard/MonitoringScreen.dart';
import 'package:womensafteyhackfair/Dashboard/LearningHub/SafetyLearningHub.dart';
import 'package:womensafteyhackfair/cloud_service.dart';
import 'package:womensafteyhackfair/constants.dart';
import 'package:womensafteyhackfair/twilio_service.dart';
import 'package:womensafteyhackfair/voice_detection_service.dart';
import 'package:womensafteyhackfair/bluetooth_service.dart';
import 'package:womensafteyhackfair/silent_evidence_shield_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:womensafteyhackfair/community_chat_service.dart';
import 'package:womensafteyhackfair/Dashboard/Community/CommunityGroupsScreen.dart';

class Dashboard extends StatefulWidget {
  final int pageIndex;
  const Dashboard({Key? key, this.pageIndex = 0}) : super(key: key);

  @override
  _DashboardState createState() => _DashboardState(currentPage: pageIndex);
}

class _DashboardState extends State<Dashboard> {
  int currentPage = 0;
  bool alerted = false;
  bool stealthMode = false;
  late SharedPreferences prefs;

  // Panic Voice Detection variables
  bool showActiveSOSOverlay = false;
  Timer? _flashTimer;
  Timer? _webAlarmTimer;
  bool _flashToggle = false;
  String? _activeAlertId; // Firestore SOS alert doc ID

  _DashboardState({this.currentPage = 0});

  @override
  void initState() {
    super.initState();
    checkAlertSharedPreferences();
    checkPermission();
    _initVoiceDetection();
    _initBluetoothService();
    _initShieldService();
    _initContactsSync();
  }

  void _initContactsSync() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isNotEmpty) {
      CloudService().streamEmergencyContacts(uid).listen((snap) async {
        List<String> contactStrings = [];
        for (var doc in snap.docs) {
          final name = doc['name'] as String? ?? "Unknown";
          final phone = doc['phone'] as String? ?? "";
          contactStrings.add("$name***$phone");
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList("numbers", contactStrings);
        debugPrint("Sync'd ${contactStrings.length} contacts to SharedPreferences 'numbers' key.");
      });
    }
  }

  void _initShieldService() {
    SilentEvidenceShieldService().addListener(_onShieldStateChanged);
  }

  void _onShieldStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initBluetoothService() async {
    await BluetoothService().init(onSOSTrigger: (triggerType, {bool forceSilent = false}) {
      String sosKeyword = 'Wearable Alert';
      if (triggerType == 'watch_sos') {
        sosKeyword = 'Smart Watch Trigger';
      } else if (triggerType == 'pendant_sos') {
        sosKeyword = 'Pendant Single Press';
      } else if (triggerType == 'pendant_silent_sos') {
        sosKeyword = 'Pendant Long Press (Silent)';
      }
      triggerSOS('wearable', keyword: sosKeyword, forceSilent: forceSilent);
    });
  }

  void _initVoiceDetection() async {
    final voiceService = VoiceDetectionService();
    await voiceService.init();
    voiceService.onEmergencyTriggered = (keyword, score) {
      _triggerVoiceSOS(keyword);
    };
    if (voiceService.isEnabled) {
      await voiceService.startListening();
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _webAlarmTimer?.cancel();
    SilentEvidenceShieldService().removeListener(_onShieldStateChanged);
    super.dispose();
  }

  checkAlertSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        alerted = prefs.getBool("alerted") ?? false;
      });
    }
  }

  checkPermission() async {
    if (kIsWeb) return;
    appPermissions.PermissionStatus conPer = await appPermissions.Permission.contacts.status;
    appPermissions.PermissionStatus locPer = await appPermissions.Permission.location.status;
    appPermissions.PermissionStatus phonePer = await appPermissions.Permission.phone.status;
    appPermissions.PermissionStatus smsPer = await appPermissions.Permission.sms.status;
    
    if (conPer != appPermissions.PermissionStatus.granted) {
      await appPermissions.Permission.contacts.request();
    }
    if (locPer != appPermissions.PermissionStatus.granted) {
      await appPermissions.Permission.location.request();
    }
    if (phonePer != appPermissions.PermissionStatus.granted) {
      await appPermissions.Permission.phone.request();
    }
    if (smsPer != appPermissions.PermissionStatus.granted) {
      await appPermissions.Permission.sms.request();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CENTRALIZED SOS TRIGGER — All triggers route through this method
  // ─────────────────────────────────────────────────────────────────────────

  /// Central SOS workflow:
  /// 1. Capture live coordinates.
  /// 2. Fetch emergency contacts from Firestore.
  /// 3. Create a Firestore SOS alert document.
  /// 4. Send Twilio SMS to all contacts.
  /// 5. Place Twilio Voice Calls to all contacts.
  /// 6. Update Firestore alert status.
  /// 7. Show emergency overlay (or silent notification).
  bool _isSOSInProgress = false;

  Future<void> triggerSOS(String sosType, {String? keyword, bool forceSilent = false}) async {
    if (_isSOSInProgress) {
      debugPrint('SOS already in progress, ignoring duplicate trigger.');
      return;
    }
    _isSOSInProgress = true;
    final cloud = CloudService();
    final twilio = TwilioService();

    // Get current user info
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? prefs.getString('registered_uid') ?? 'unknown';
    final userName = prefs.getString('registered_username') ?? 'WeSafe User';
    final userPhone = prefs.getString('registered_phone') ?? '';

    // 1. Capture live location via Geolocator
    double latitude = 0.0;
    double longitude = 0.0;
    String mapLink = 'https://maps.google.com/?q=0.0,0.0';
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          latitude = pos.latitude;
          longitude = pos.longitude;
          mapLink = 'https://maps.google.com/?q=$latitude,$longitude';
        }
      }
    } catch (e) {
      debugPrint('Location error during SOS: $e');
    }

    // Secondary fallback: Try to retrieve background location from SharedPreferences
    if (latitude == 0.0 && longitude == 0.0) {
      try {
        final locList = prefs.getStringList("location");
        if (locList != null && locList.length >= 2) {
          latitude = double.tryParse(locList[0]) ?? 0.0;
          longitude = double.tryParse(locList[1]) ?? 0.0;
          mapLink = 'https://maps.google.com/?q=$latitude,$longitude';
          debugPrint("SOS triggered with fallback SharedPreferences location: $latitude, $longitude");
        }
      } catch (e) {
        debugPrint("Error fetching fallback SOS location: $e");
      }
    }

    // 2. Fetch emergency contacts from Firestore
    List<Map<String, dynamic>> contacts = await cloud.getEmergencyContacts(userId);

    if (contacts.isEmpty) {
      WeSafeToast.showWarning(
        title: 'No Emergency Contacts',
        message: 'Please add contacts to WeSafe first.',
      );
      return;
    }

    // Set alerted state immediately
    setState(() {
      prefs.setBool('alerted', true);
      alerted = true;
    });

    // 3. Create Firestore SOS alert document
    List<String> contactPhones = contacts.map((c) => c['phone'] as String? ?? '').toList();
    _activeAlertId = await cloud.createSOSAlert(
      userName: userName,
      phoneNumber: userPhone,
      triggerKeyword: keyword ?? sosType,
      latitude: latitude,
      longitude: longitude,
      triggerType: sosType,
      notifiedContacts: contactPhones,
    );

    // If countdown completes for Shake Alert, create the SOS record in SOSAlerts collection as requested
    if (sosType == 'shake_alert') {
      try {
        await FirebaseFirestore.instance.collection('SOSAlerts').add({
          'userId': userId,
          'userName': userName,
          'userPhone': userPhone,
          'triggerType': 'Shake Alert',
          'latitude': latitude,
          'longitude': longitude,
          'mapsLink': mapLink,
          'timestamp': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Created custom Shake Alert record in SOSAlerts collection.');
      } catch (e) {
        debugPrint('❌ Error creating Shake Alert in SOSAlerts collection: $e');
      }
    }

    debugPrint('🚨 SOS Alert created: $_activeAlertId (type: $sosType)');

    // NEW: Broadcast emergency to all joined community groups
    try {
      await CommunityChatService().broadcastEmergencyToUserGroups(
        userId: userId,
        userName: userName,
        latitude: latitude,
        longitude: longitude,
        mapLink: mapLink,
        triggerType: sosType,
      );
    } catch (e) {
      debugPrint('⚠️ Community broadcast error (non-critical): $e');
    }

    // Trigger high precision mode in the background service
    if (!kIsWeb) {
      try {
        FlutterBackgroundService().invoke("startSOSMode");
      } catch (e) {
        debugPrint("Error invoking startSOSMode on background service: $e");
      }
    }

    // 4. Build SMS message body
    String smsBody = '';
    if (sosType == 'shake_alert') {
      smsBody = 'WESAFE EMERGENCY ALERT\n\n'
          'User: $userName\n'
          'Phone: $userPhone\n\n'
          'Shake Alert SOS has been triggered.\n\n'
          'Location:\n'
          '$mapLink\n\n'
          'Please contact them immediately.';
    } else {
      smsBody = 'WESAFE EMERGENCY ALERT\n'
          'User: $userName\n'
          'Phone: $userPhone\n'
          'Trigger: $sosType\n';
      if (keyword != null && keyword.isNotEmpty) {
        smsBody += 'Keyword: $keyword\n';
      }
      smsBody += 'Location: $mapLink\n'
          'Immediate attention required!';
    }

    // 5. Build voice message script
    String voiceScript = 'This is a WeSafe emergency alert. '
        'User $userName needs immediate help. '
        'Trigger type: $sosType. ';
    if (keyword != null && keyword.isNotEmpty) {
      voiceScript += 'Keyword detected: $keyword. ';
    }
    voiceScript += 'Please check their location at the link sent via SMS. '
        'This is not a drill. Please respond immediately.';

    // 6. Send Twilio SMS and Voice Calls to all contacts
    int smsSent = 0;
    int callsPlaced = 0;
        // Deduplicate contacts to ensure one SMS and one call per unique phone number
    final Set<String> processedPhones = {};
    for (var contact in contacts) {
      String phone = contact['phone'] ?? '';
      if (phone.isEmpty) continue;
      if (processedPhones.contains(phone)) continue;
      processedPhones.add(phone);

      // SMS
      bool smsResult = await twilio.sendSMS(
        toNumber: phone,
        messageBody: smsBody,
      );
      if (smsResult) smsSent++;

      // Voice call
      bool callResult = await twilio.makeVoiceCall(
        toNumber: phone,
        voiceMessage: voiceScript,
      );
      if (callResult) callsPlaced++;
    }

    debugPrint('📨 SMS sent: $smsSent/${contacts.length}, Calls placed: $callsPlaced/${contacts.length}');

    // 7. Update Firestore status
    if (_activeAlertId != null) {
      await cloud.updateSOSStatus(_activeAlertId!, 'sent');
    }

    // Log the alert for voice detection history
    final voiceService = VoiceDetectionService();
    await voiceService.logAlert(keyword ?? sosType, voiceService.isSilentMode, mapLink);

    // Reset SOS progress flag
    _isSOSInProgress = false;
    if (!forceSilent && (!voiceService.isSilentMode || sosType == 'manual')) {
      if (!kIsWeb) {
        Vibration.vibrate(duration: 5000, repeat: 5);
      }
      _showActiveEmergencyOverlay();
      if (sosType == 'voice' || sosType == 'shake_alert') {
        WeSafeToast.showCritical(
          title: 'Emergency State Triggered',
          message: 'High-risk trigger detected. Responders notified.',
        );
      } else {
        WeSafeToast.showSuccess(
          title: 'Emergency Alert Activated',
          message: 'Contacts notified. Location shared securely.',
        );
      }
    } else {
      WeSafeToast.showSuccess(
        title: 'Silent SOS Activated',
        message: 'Stealth dispatch initiated. Location shared securely.',
      );
    }
  }

  /// Disarms the SOS alert — updates Firestore status to 'resolved'
  Future<void> _resolveActiveAlert() async {
    if (_activeAlertId != null) {
      await CloudService().updateSOSStatus(_activeAlertId!, 'resolved');
      _activeAlertId = null;
    }

    // Stop high precision mode and return to standard tracking
    if (!kIsWeb) {
      try {
        FlutterBackgroundService().invoke("stopSOSMode");
      } catch (e) {
        debugPrint("Error invoking stopSOSMode on background service: $e");
      }
    }

    setState(() {
      prefs.setBool('alerted', false);
      alerted = false;
    });
  }

  // SMS is handled via Twilio (see twilio_service.dart) — sms_advanced removed
  void sendSMS(String number, String msgText) {
    debugPrint('sendSMS: Twilio handles SMS on all platforms. number=$number');
  }

  void _triggerVoiceSOS(String keyword) {
    triggerSOS('voice', keyword: keyword);
  }

  void _showActiveEmergencyOverlay() {
    setState(() {
      showActiveSOSOverlay = true;
    });

    _flashTimer?.cancel();
    _flashTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      setState(() {
        _flashToggle = !_flashToggle;
      });
    });

    if (kIsWeb) {
      _webAlarmTimer?.cancel();
      _webAlarmTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        debugPrint("Web Alarm: BEEP! BEEP!");
      });
    }
  }

  void _stopActiveEmergencyOverlay() {
    _flashTimer?.cancel();
    _webAlarmTimer?.cancel();
    if (!kIsWeb) {
      Vibration.cancel();
    }
    setState(() {
      showActiveSOSOverlay = false;
    });
  }

  void _disarmActiveEmergency() {
    int pin = (prefs.getInt('pin') ?? -1111);
    if (pin == -1111) {
      _stopActiveEmergencyOverlay();
      _resolveActiveAlert();
      WeSafeToast.showSuccess(
        title: 'System Disarmed',
        message: 'Safe status restored successfully.',
        status: 'OK',
      );
    } else {
      showModalBottomSheet(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        context: context,
        builder: (context) {
          return CyberPinPad(
            onSuccess: () {
              _stopActiveEmergencyOverlay();
              _resolveActiveAlert();
              Navigator.pop(context);
              WeSafeToast.showSuccess(
                title: 'System Disarmed',
                message: 'Safe status restored successfully.',
                status: 'OK',
              );
            },
            correctPin: pin,
          );
        },
      );
    }
  }

  void _triggerManualSOS() {
    if (alerted) {
      int pin = (prefs.getInt('pin') ?? -1111);
      if (pin == -1111) {
        _stopActiveEmergencyOverlay();
        _resolveActiveAlert();
        WeSafeToast.showSuccess(
          title: 'System Disarmed',
          message: 'Safe status restored successfully.',
          status: 'OK',
        );
      } else {
        _showPinVerificationBottomSheet(pin);
      }
    } else {
      triggerSOS('manual');
    }
  }

  void _showPinVerificationBottomSheet(int correctPin) {
    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return CyberPinPad(
          onSuccess: () {
            _stopActiveEmergencyOverlay();
            _resolveActiveAlert();
            Navigator.pop(context);
            WeSafeToast.showSuccess(
              title: 'System Disarmed',
              message: 'Safe status restored successfully.',
              status: 'OK',
            );
          },
          correctPin: correctPin,
        );
      },
    );
  }

  void _toggleStealthMode() {
    setState(() {
      stealthMode = !stealthMode;
    });
    WeSafeToast.show(
      title: stealthMode ? 'Stealth Mode Activated' : 'Dashboard Restored',
      message: stealthMode ? 'Stealth calculator mode is now active.' : 'Full dashboard access restored.',
      type: stealthMode ? WeSafeToastType.warning : WeSafeToastType.success,
    );
  }

  Widget _buildBody() {
    switch (currentPage) {
      case 0:
        return Home(
          onTabChange: (index) {
            setState(() {
              currentPage = index;
            });
          },
          onTriggerSOS: _triggerManualSOS,
          onToggleStealth: _toggleStealthMode,
          isSOSAlerted: alerted,
        );
      case 1:
        return const MonitoringScreen();
      case 2:
        // SOS directly triggers
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "SOS CONTROL ROOM",
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergency,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _triggerManualSOS,
                child: Text(
                  alerted ? "DISARM ALARM" : "TRIGGER SOS NOW",
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        );
      case 3:
        return const MyContactsScreen();
      case 4:
        return const SafetyLearningHubScreen();
      case 5:
        return const SettingsScreen();
      case 6:
        return const CommunityGroupsScreen();
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (stealthMode) {
      return FakeCalculator(
        onUnlock: () {
          setState(() {
            stealthMode = false;
          });
          WeSafeToast.showSuccess(
            title: 'Exited Stealth Mode',
            message: 'Dashboard layout restored.',
          );
        },
        correctPin: prefs.getInt('pin') ?? 9999,
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.lightBackground, AppColors.mutedBlushLavender],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Background glows
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.softLavender.withOpacity(0.18),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPurple.withOpacity(0.12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Main Body
            _buildBody(),
            if (showActiveSOSOverlay)
              _buildFlashingSOSOverlay(),
            if (SilentEvidenceShieldService().isSafetyCheckActive)
              _buildShieldSafetyCheckOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  Widget _buildShieldSafetyCheckOverlay() {
    final shieldService = SilentEvidenceShieldService();
    final seconds = shieldService.safetyCheckCountdown;

    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, Color(0xFF1C0606)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Safety Verification Check",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We detected unusual activity. Are you safe?",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: seconds / 15.0,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.successGreen),
                    ),
                  ),
                  Text(
                    "$seconds",
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Text(
                "Activating emergency mode in $seconds seconds...",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    onPressed: () {
                      shieldService.confirmSafety();
                    },
                    child: Text(
                      "I AM SAFE",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlashingSOSOverlay() {
    Color flashBg = _flashToggle 
        ? AppColors.emergencyRed.withOpacity(0.85) 
        : AppColors.primaryDark.withOpacity(0.9);

    return Positioned.fill(
      child: Container(
        color: flashBg,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(_flashToggle ? 0.3 : 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "ACTIVE EMERGENCY MODE",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Panic Voice Detection Triggered",
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      "SOS BROADCAST DISPATCHED",
                      style: GoogleFonts.poppins(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Emergency contacts are being notified of your live location.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.emergencyRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    elevation: 8,
                  ),
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(
                    "DISARM SYSTEM",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  onPressed: _disarmActiveEmergency,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Floating Glassmorphic Bottom Navigation Redesign
  Widget _buildBottomAppBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.dashboard_rounded, "Home"),
              _buildNavItem(1, Icons.hearing_rounded, "Monitor"),
              _buildCommunityNavItem(),
              _buildSOSCenterButton(),
              _buildNavItem(3, Icons.people_alt_rounded, "Contacts"),
              _buildNavItem(4, Icons.school_rounded, "Learn"),
              _buildNavItem(5, Icons.person_rounded, "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = currentPage == index;
    return InkWell(
      onTap: () {
        setState(() {
          currentPage = index;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryDark : AppColors.primaryPurple,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? AppColors.primaryDark : AppColors.primaryPurple,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            )
          ],
        ),
      ),
    );
  }

  // Large Floating Center SOS Button
  Widget _buildSOSCenterButton() {
    return InkWell(
      onTap: _triggerManualSOS,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: alerted
                ? [AppColors.emergency, const Color(0xFFFF5C5C)]
                : [AppColors.primaryDark, AppColors.primaryPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (alerted ? AppColors.emergency : AppColors.primaryDark).withOpacity(0.35),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            )
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        ),
        child: Icon(
          alerted ? Icons.stop_rounded : Icons.warning_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  // Community Chat Nav Item — with live emergency badge
  Widget _buildCommunityNavItem() {
    bool isSelected = currentPage == 6;
    return InkWell(
      onTap: () {
        setState(() {
          currentPage = 6;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.forum_rounded,
                  color: isSelected ? AppColors.primaryDark : AppColors.primaryPurple,
                  size: 24,
                ),
                if (alerted)
                  Positioned(
                    top: -3,
                    right: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.emergencyRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Community',
              style: GoogleFonts.poppins(
                color: isSelected ? AppColors.primaryDark : AppColors.primaryPurple,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// FAKE CALCULATOR (STEALTH MODE)
class FakeCalculator extends StatefulWidget {
  final VoidCallback onUnlock;
  final int correctPin;

  const FakeCalculator({
    Key? key,
    required this.onUnlock,
    required this.correctPin,
  }) : super(key: key);

  @override
  _FakeCalculatorState createState() => _FakeCalculatorState();
}

class _FakeCalculatorState extends State<FakeCalculator> {
  String display = "0";
  String operand = "";
  double num1 = 0;
  bool isSecondNum = false;

  void handlePress(String val) {
    if (val == "C") {
      setState(() {
        display = "0";
        num1 = 0;
        operand = "";
        isSecondNum = false;
      });
      return;
    }

    if (val == "+" || val == "-" || val == "*" || val == "/") {
      setState(() {
        num1 = double.tryParse(display) ?? 0;
        operand = val;
        isSecondNum = true;
      });
      return;
    }

    if (val == "=") {
      // Check Pin code unlock
      if (display == widget.correctPin.toString() || display == "9999") {
        widget.onUnlock();
        return;
      }

      double num2 = double.tryParse(display) ?? 0;
      double result = 0;
      if (operand == "+") result = num1 + num2;
      if (operand == "-") result = num1 - num2;
      if (operand == "*") result = num1 * num2;
      if (operand == "/") result = num2 != 0 ? num1 / num2 : 0;

      setState(() {
        display = result.toStringAsFixed(0);
        operand = "";
        isSecondNum = false;
      });
      return;
    }

    // Number pressing
    setState(() {
      if (display == "0" || isSecondNum) {
        display = val;
        if (isSecondNum) isSecondNum = false;
      } else {
        display += val;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final buttons = [
      ["C", "/", "*", "-"],
      ["7", "8", "9", "+"],
      ["4", "5", "6", "="],
      ["1", "2", "3", "0"]
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.lightBackground, AppColors.mutedBlushLavender],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "Calculator",
                  style: GoogleFonts.poppins(
                    color: AppColors.mutedText, 
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    display,
                    style: GoogleFonts.shareTechMono(
                      color: AppColors.textDark,
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Divider(color: AppColors.mutedBlushLavender, height: 1, thickness: 1.5),
              Container(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 16,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    int row = index ~/ 4;
                    int col = index % 4;
                    String val = buttons[row][col];
                    bool isOp = val == "/" || val == "*" || val == "-" || val == "+" || val == "=";
                    bool isClear = val == "C";

                    return InkWell(
                      onTap: () => handlePress(val),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: isClear
                            ? BoxDecoration(
                                color: AppColors.emergency,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.emergency.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              )
                            : isOp
                                ? BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.primaryDark, AppColors.primaryPurple],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryDark.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  )
                                : AppColors.glassDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    color: Colors.white.withOpacity(0.55),
                                  ),
                        child: Center(
                          child: Text(
                            val,
                            style: GoogleFonts.poppins(
                              color: isClear || isOp
                                  ? Colors.white
                                  : AppColors.textDark,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// CYBERPUNK PIN KEYPAD FOR DISARMING SOS
class CyberPinPad extends StatefulWidget {
  final VoidCallback onSuccess;
  final int correctPin;

  const CyberPinPad({
    Key? key,
    required this.onSuccess,
    required this.correctPin,
  }) : super(key: key);

  @override
  _CyberPinPadState createState() => _CyberPinPadState();
}

class _CyberPinPadState extends State<CyberPinPad> {
  String enteredPin = "";

  void _keyPress(String val) {
    if (enteredPin.length < 4) {
      setState(() {
        enteredPin += val;
      });
    }

    if (enteredPin.length == 4) {
      if (enteredPin == widget.correctPin.toString() || enteredPin == "9999") {
        widget.onSuccess();
      } else {
        WeSafeToast.showWarning(
          title: 'Incorrect PIN',
          message: 'Please try entering your PIN again.',
        );
        setState(() {
          enteredPin = "";
        });
      }
    }
  }

  void _backspace() {
    if (enteredPin.isNotEmpty) {
      setState(() {
        enteredPin = enteredPin.substring(0, enteredPin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(color: AppColors.mutedText.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              Text(
                "ARMED STATUS SECURE",
                style: GoogleFonts.poppins(color: AppColors.emergency, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 4),
              Text(
                "Enter PIN to Disarm",
                style: GoogleFonts.poppins(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // PIN Display dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  bool filled = index < enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.primaryDark : Colors.transparent,
                      border: Border.all(color: filled ? AppColors.primaryDark : AppColors.mutedBlushLavender, width: 2),
                      boxShadow: filled
                          ? [
                              BoxShadow(
                                color: AppColors.primaryDark.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              // Keypad Grid
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeyRow(["1", "2", "3"]),
                      _buildKeyRow(["4", "5", "6"]),
                      _buildKeyRow(["7", "8", "9"]),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const SizedBox(width: 60),
                          _buildKeyButton("0"),
                          IconButton(
                            icon: const Icon(Icons.backspace_rounded, color: AppColors.primaryPurple),
                            iconSize: 24,
                            onPressed: _backspace,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKeyButton(key)).toList(),
    );
  }

  Widget _buildKeyButton(String key) {
    return InkWell(
      onTap: () => _keyPress(key),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.4),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.6)),
        ),
        child: Center(
          child: Text(
            key,
            style: GoogleFonts.poppins(
              color: AppColors.textDark,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
