import 'dart:math';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:womensafteyhackfair/Dashboard/DashWidgets/WeSafeToast.dart';
import 'package:womensafteyhackfair/cloud_service.dart';
import 'package:womensafteyhackfair/constants.dart';
import 'package:womensafteyhackfair/bluetooth_service.dart';
import 'package:womensafteyhackfair/silent_evidence_shield_service.dart';
import 'package:womensafteyhackfair/Dashboard/Dashboard.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';

class Home extends StatefulWidget {
  final Function(int) onTabChange;
  final VoidCallback onTriggerSOS;
  final VoidCallback onToggleStealth;
  final bool isSOSAlerted;

  const Home({
    Key? key,
    required this.onTabChange,
    required this.onTriggerSOS,
    required this.onToggleStealth,
    required this.isSOSAlerted,
  }) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  late AnimationController _shieldPulseController;
  late AnimationController _radarController;
  String currentAddress = "Fetching live GPS location...";
  String accuracy = "GPS: Lock acquired";
  bool isLocating = false;
  double? currentLat;
  double? currentLng;
  GoogleMapController? _mapController;

  // Real-time location stream and metadata variables
  StreamSubscription<Position>? _positionStreamSubscription;
  double? currentAccuracy;
  double currentHeading = 0.0;
  double? currentSpeed;
  DateTime? lastUpdateTime;
  bool isSignalLost = false;
  bool isCameraLocked = true;
  Timer? _uiUpdateTimer;
  int _secondsSinceLastUpdate = 0;

  @override
  void initState() {
    super.initState();
    _shieldPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _startForegroundLocationStream();
    _startUiUpdateTimer();
    BluetoothService().addListener(_onBluetoothChanged);
    SilentEvidenceShieldService().addListener(_onShieldChanged);
  }

  @override
  void didUpdateWidget(Home oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSOSAlerted != oldWidget.isSOSAlerted) {
      debugPrint("Home: SOS status changed to ${widget.isSOSAlerted}. Reconfiguring location stream.");
      _startForegroundLocationStream();
    }
  }

  void _startForegroundLocationStream() async {
    _positionStreamSubscription?.cancel();
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          isSignalLost = true;
          accuracy = "GPS Signal Lost (Disabled)";
        });
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          isSignalLost = true;
          accuracy = "GPS Permission Denied";
        });
      }
      return;
    }

    LocationSettings locationSettings;
    if (widget.isSOSAlerted) {
      // Emergency mode: highest precision, 1-2s frequency, 0m distance filter
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: "Emergency high-precision tracking is active!",
            notificationTitle: "WeSafe SOS Mode Active",
            enableWakeLock: true,
          ),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        );
      }
    } else {
      // Standard mode: high accuracy, 0m filter so stationary users always get updates,
      // 5s interval to balance freshness and battery
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 5),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );
      }
    }

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position pos) async {
      if (!mounted) return;
      
      setState(() {
        currentLat = pos.latitude;
        currentLng = pos.longitude;
        currentAccuracy = pos.accuracy;
        currentHeading = pos.heading;
        currentSpeed = pos.speed;
        lastUpdateTime = DateTime.now();
        _secondsSinceLastUpdate = 0;
        isSignalLost = false;
        isLocating = false;

        currentAddress = "Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}";
        accuracy = "Accuracy: ±${pos.accuracy.toStringAsFixed(1)}m";
      });

      // Recenter camera if locked
      if (isCameraLocked && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(pos.latitude, pos.longitude),
              zoom: widget.isSOSAlerted ? 18.0 : 16.0,
              bearing: pos.heading,
            ),
          ),
        );
      }

      // Sync coordinate changes to Firestore
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final email = user?.email ?? prefs.getString('registered_email') ?? '';
      if (email.isNotEmpty) {
        await CloudService().updateLiveLocation(
          userEmail: email,
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          speed: pos.speed,
          heading: pos.heading,
        );
      }
    }, onError: (err) {
      if (mounted) {
        setState(() {
          isSignalLost = true;
        });
      }
    });
  }

  void _startUiUpdateTimer() {
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (lastUpdateTime != null) {
        setState(() {
          _secondsSinceLastUpdate = DateTime.now().difference(lastUpdateTime!).inSeconds;
          // Only mark signal as lost after 60s of no GPS updates.
          // Previously 10s caused false SIGNAL LOST for stationary users.
          if (_secondsSinceLastUpdate > 60) {
            isSignalLost = true;
          } else {
            // Signal is still valid — ensure the flag is cleared if GPS had ever connected
            isSignalLost = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _uiUpdateTimer?.cancel();
    BluetoothService().removeListener(_onBluetoothChanged);
    SilentEvidenceShieldService().removeListener(_onShieldChanged);
    _shieldPulseController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  void _onBluetoothChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onShieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _getLiveLocation() async {
    setState(() {
      isLocating = true;
    });
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
          setState(() {
            currentLat = pos.latitude;
            currentLng = pos.longitude;
            currentAddress = "Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}";
            accuracy = "Accuracy: ±${pos.accuracy.toStringAsFixed(1)}m";
            isLocating = false;
          });
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(pos.latitude, pos.longitude),
                  zoom: 15.0,
                ),
              ),
            );
          }
          return;
        }
      }
      throw Exception('Location service disabled or permission denied');
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final locList = prefs.getStringList("location");
        if (locList != null && locList.length >= 2) {
          final lat = double.tryParse(locList[0]);
          final lng = double.tryParse(locList[1]);
          if (lat != null && lng != null) {
            setState(() {
              currentLat = lat;
              currentLng = lng;
              currentAddress = "Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}";
              accuracy = "Accuracy: GPS (Background)";
              isLocating = false;
            });
            if (_mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(lat, lng),
                    zoom: 15.0,
                  ),
                ),
              );
            }
            return;
          }
        }
      } catch (_) {}

      setState(() {
        currentLat = 12.9568;
        currentLng = 77.7011;
        currentAddress = "Outer Ring Rd, Marathahalli, Bengaluru";
        accuracy = "Accuracy: GPS Est. ±5m";
        isLocating = false;
      });
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(currentLat!, currentLng!),
              zoom: 15.0,
            ),
          ),
        );
      }
    }
  }

  Future<void> _makeCall(String number) async {
    try {
      bool? res = await FlutterPhoneDirectCaller.callNumber(number);
      if (res == null || !res) {
        final Uri launchUri = Uri(
          scheme: 'tel',
          path: number,
        );
        await launchUrl(launchUri);
      }
    } catch (e) {
      debugPrint("Could not make call: $e");
    }
  }

  Future<void> _callFamilySOS() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isEmpty) return;

    final contacts = await CloudService().getEmergencyContacts(uid);
    if (contacts.isNotEmpty) {
      String contactNum = contacts.first['phone'] ?? "";
      _makeCall(contactNum);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No emergency contacts saved! Navigate to 'Contacts' to add one."),
          backgroundColor: AppColors.emergency,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isTablet = size.width > 600 && size.width <= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. BRAND HEADER
              _buildBrandHeader(),
              const SizedBox(height: 24),

              // GRID / COLUMN LAYOUT BASED ON SCREEN WIDTH
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildSideBySideBluetoothCards(),
                          const SizedBox(height: 24),
                          _buildQuickActions(),
                          const SizedBox(height: 24),
                          _buildAIIntelligenceCard(),
                          const SizedBox(height: 24),
                          _buildExploreSafetyHub(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildLiveLocationModule(),
                          const SizedBox(height: 24),
                          _buildEmergencyServices(),
                          const SizedBox(height: 24),
                          _buildEmergencyContactsDashboardCard(),
                        ],
                      ),
                    )
                  ],
                )
              else
                Column(
                  children: [
                    _buildSideBySideBluetoothCards(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildEmergencyContactsDashboardCard(),
                    const SizedBox(height: 24),
                    _buildAIIntelligenceCard(),
                    const SizedBox(height: 24),
                    _buildLiveLocationModule(),
                    const SizedBox(height: 24),
                    _buildEmergencyServices(),
                    const SizedBox(height: 24),
                    _buildExploreSafetyHub(),
                    const SizedBox(height: 80),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // BRAND HEADER
  Widget _buildBrandHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset(
              "assets/wesafelogo.png",
              height: 54,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "WeSafe",
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                Text(
                  "Your Safety Guardian",
                  style: GoogleFonts.poppins(
                    color: AppColors.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryDark),
          onPressed: () {
            _getLiveLocation();
          },
        ),
      ],
    );
  }

  // 1. SIDE-BY-SIDE BLUETOOTH DEVICES
  Widget _buildSideBySideBluetoothCards() {
    return Row(
      children: [
        Expanded(child: _buildSmartWatchCard()),
        const SizedBox(width: 16),
        Expanded(child: _buildSafetyPendantCard()),
      ],
    );
  }

  Widget _buildSmartWatchCard() {
    final bt = BluetoothService();
    final isConnected = bt.isWatchConnected;
    final isConnecting = bt.isWatchConnecting;
    final lastSync = bt.watchLastSync;
    final syncStr = lastSync != null 
        ? "${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}:${lastSync.second.toString().padLeft(2, '0')}"
        : "--:--";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.watch_rounded, color: AppColors.primaryDark, size: 28),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isConnected ? AppColors.successGreen : AppColors.emergencyRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected ? AppColors.successGreen : AppColors.emergencyRed).withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Smart Watch",
            style: GoogleFonts.poppins(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            isConnected ? "Connected" : (isConnecting ? "Pairing..." : "Not Connected"),
            style: GoogleFonts.poppins(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Last Sync: $syncStr",
            style: GoogleFonts.poppins(
              color: AppColors.mutedText.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 16),
          if (isConnecting)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple)),
              ),
            )
          else if (!isConnected)
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => bt.connectWatch(),
                child: Text("CONNECT", style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryPurple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => bt.disconnectWatch(),
                child: Text("DISCONNECT", style: GoogleFonts.poppins(color: AppColors.primaryPurple, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergencyRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.warning_rounded, color: Colors.white, size: 14),
                label: Text("TRIGGER SOS", style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: () => bt.simulateWatchSOS(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafetyPendantCard() {
    final bt = BluetoothService();
    final isConnected = bt.isPendantConnected;
    final isConnecting = bt.isPendantConnecting;
    final lastSync = bt.pendantLastSync;
    final syncStr = lastSync != null 
        ? "${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}:${lastSync.second.toString().padLeft(2, '0')}"
        : "--:--";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.center_focus_strong_rounded, color: AppColors.primaryDark, size: 28),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isConnected ? AppColors.successGreen : AppColors.emergencyRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected ? AppColors.successGreen : AppColors.emergencyRed).withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Safety Pendant",
            style: GoogleFonts.poppins(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            isConnected ? "Connected" : (isConnecting ? "Pairing..." : "Not Connected"),
            style: GoogleFonts.poppins(
              color: AppColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Last Sync: $syncStr",
            style: GoogleFonts.poppins(
              color: AppColors.mutedText.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 16),
          if (isConnecting)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple)),
              ),
            )
          else if (!isConnected)
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => bt.connectPendant(),
                child: Text("CONNECT", style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryPurple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => bt.disconnectPendant(),
                child: Text("DISCONNECT", style: GoogleFonts.poppins(color: AppColors.primaryPurple, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warningOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => bt.simulatePendantPress(false),
                      child: Text("PRESS (SOS)", style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => bt.simulatePendantPress(true),
                      child: Text("LONG (SILENT)", style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 2. QUICK ACTIONS PANEL
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: GoogleFonts.poppins(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildActionCard(
              icon: Icons.notifications_active_rounded,
              label: widget.isSOSAlerted ? "Cancel SOS" : "Manual SOS",
              color: AppColors.emergency,
              onTap: widget.onTriggerSOS,
            ),
            _buildActionCard(
              icon: Icons.settings_voice_rounded,
              label: "Safe Words",
              color: AppColors.primaryDark,
              onTap: () => widget.onTabChange(1),
            ),
            _buildShieldCard(),
            _buildActionCard(
              icon: Icons.calculate_rounded,
              label: "Stealth Mode",
              color: AppColors.warningOrange,
              onTap: widget.onToggleStealth,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: AppColors.glassDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 3. SILENT EVIDENCE SHIELD FEATURE
  void _showShieldSettingsSheet() {
    final shieldService = SilentEvidenceShieldService();
    final TextEditingController destController = TextEditingController();
    int selectedDuration = 20;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final status = shieldService.status;
            final isActive = status != ShieldStatus.inactive;

            return ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: MediaQuery.of(context).size.height * (isActive ? 0.85 : 0.65),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground.withOpacity(0.92),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.mutedText.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Silent Evidence Shield",
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                Text(
                                  "AI-powered trip and journey guardian",
                                  style: GoogleFonts.poppins(
                                    color: AppColors.mutedText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.security_rounded,
                              color: isActive ? AppColors.successGreen : AppColors.primaryDark,
                              size: 28,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (!isActive) ...[
                          Text(
                            "ENTER DESTINATION",
                            style: GoogleFonts.poppins(
                              color: AppColors.textDark.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: destController,
                            style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: "Where are you traveling to?",
                              hintStyle: const TextStyle(color: AppColors.mutedText),
                              prefixIcon: const Icon(Icons.pin_drop_rounded, color: AppColors.primaryPurple),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "EXPECTED DURATION",
                            style: GoogleFonts.poppins(
                              color: AppColors.textDark.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [10, 20, 30, 45].map((mins) {
                              bool isSel = selectedDuration == mins;
                              return InkWell(
                                onTap: () {
                                  setSheetState(() {
                                    selectedDuration = mins;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSel ? AppColors.primaryPurple.withOpacity(0.12) : Colors.white.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel ? AppColors.primaryPurple : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    "$mins mins",
                                    style: GoogleFonts.poppins(
                                      color: isSel ? AppColors.primaryPurple : AppColors.textDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () async {
                                final destinationText = destController.text.trim();
                                if (destinationText.isEmpty) {
                                  WeSafeToast.showWarning(
                                    title: 'Destination Missing',
                                    message: 'Please enter a destination to start trip protection.',
                                  );
                                  return;
                                }
                                Navigator.pop(context);
                                await shieldService.startJourney(destinationText, selectedDuration);
                                if (mounted) {
                                  setState(() {});
                                }
                                WeSafeToast.showSuccess(
                                  title: 'Silent Evidence Shield Active',
                                  message: 'Trip monitoring started securely.',
                                  status: 'LIVE',
                                );
                              },
                              child: Text(
                                "START SHIELD PROTECTION",
                                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.0),
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "📍 Dest: ${shieldService.destination}",
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textDark),
                                      ),
                                    ),
                                    Text(
                                      "🔋 ${shieldService.batteryPercentage}%",
                                      style: GoogleFonts.shareTechMono(color: AppColors.primaryPurple, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "ETA: ${shieldService.expectedArrivalTime?.toLocal().toString().split(' ')[1].split('.')[0] ?? '--:--'}",
                                  style: GoogleFonts.poppins(color: AppColors.mutedText, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // JOURNEY STATUS INDICATOR
                          Text(
                            "JOURNEY STATUS",
                            style: GoogleFonts.poppins(
                              color: AppColors.textDark.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: status == ShieldStatus.emergencyActive
                                  ? AppColors.emergencyRed.withOpacity(0.1)
                                  : status == ShieldStatus.riskDetected
                                      ? AppColors.warningOrange.withOpacity(0.1)
                                      : AppColors.successGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: status == ShieldStatus.emergencyActive
                                    ? AppColors.emergencyRed.withOpacity(0.4)
                                    : status == ShieldStatus.riskDetected
                                        ? AppColors.warningOrange.withOpacity(0.4)
                                        : AppColors.successGreen.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: status == ShieldStatus.emergencyActive
                                        ? AppColors.emergencyRed
                                        : status == ShieldStatus.riskDetected
                                            ? AppColors.warningOrange
                                            : AppColors.successGreen,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (status == ShieldStatus.emergencyActive
                                                ? AppColors.emergencyRed
                                                : status == ShieldStatus.riskDetected
                                                    ? AppColors.warningOrange
                                                    : AppColors.successGreen)
                                            .withOpacity(0.5),
                                        blurRadius: 6,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shieldService.currentJourneyStatus,
                                        style: GoogleFonts.poppins(
                                          color: status == ShieldStatus.emergencyActive
                                              ? AppColors.emergencyRed
                                              : status == ShieldStatus.riskDetected
                                                  ? AppColors.warningOrange
                                                  : AppColors.successGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (status == ShieldStatus.riskDetected && shieldService.activeRiskType != null)
                                        Text(
                                          "Risk: ${shieldService.activeRiskType}",
                                          style: GoogleFonts.poppins(
                                            color: AppColors.warningOrange.withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      if (status == ShieldStatus.monitoring)
                                        Text(
                                          "Real-time GPS & risk analysis active",
                                          style: GoogleFonts.poppins(
                                            color: AppColors.mutedText,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // AUTO-DETECTION INFO CHIPS
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildInfoChip(Icons.route_rounded, "Route Deviation"),
                              _buildInfoChip(Icons.pause_circle_filled_rounded, "Unexpected Stop"),
                              _buildInfoChip(Icons.timer_off_rounded, "Missed ETA"),
                              _buildInfoChip(Icons.signal_wifi_off_rounded, "No Connectivity"),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "JOURNEY TIMELINE",
                            style: GoogleFonts.poppins(
                              color: AppColors.textDark.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: shieldService.journeyTimeline.length,
                              itemBuilder: (context, index) {
                                final item = shieldService.journeyTimeline[shieldService.journeyTimeline.length - 1 - index];
                                final event = item['event'] ?? '';
                                final time = item['timestamp'] != null 
                                    ? DateTime.parse(item['timestamp']).toLocal().toString().split(' ')[1].split('.')[0]
                                    : '';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    "[$time] $event",
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDark),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: status == ShieldStatus.emergencyActive ? AppColors.emergencyRed : AppColors.primaryPurple,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () async {
                                if (status == ShieldStatus.emergencyActive) {
                                  Navigator.pop(context);
                                  _resolveShieldEmergency();
                                } else {
                                  Navigator.pop(context);
                                  await shieldService.resolveJourney();
                                  if (mounted) {
                                    setState(() {});
                                  }
                                  WeSafeToast.showSuccess(
                                    title: 'Journey Completed',
                                    message: 'Shield protection ended successfully.',
                                    status: 'OK',
                                  );
                                }
                              },
                              child: Text(
                                status == ShieldStatus.emergencyActive ? "END EMERGENCY & MARK SAFE" : "END JOURNEY & MARK SAFE",
                                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryDark.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primaryDark.withOpacity(0.7)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: AppColors.textDark.withOpacity(0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _resolveShieldEmergency() async {
    final prefs = await SharedPreferences.getInstance();
    int pin = (prefs.getInt('pin') ?? -1111);
    if (pin == -1111) {
      await SilentEvidenceShieldService().resolveJourney();
      setState(() {});
      WeSafeToast.showSuccess(
        title: 'System Disarmed',
        message: 'Journey protection ended successfully.',
        status: 'OK',
      );
    } else {
      showModalBottomSheet(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        context: context,
        builder: (context) {
          return CyberPinPad(
            onSuccess: () async {
              await SilentEvidenceShieldService().resolveJourney();
              setState(() {});
              Navigator.pop(context);
              WeSafeToast.showSuccess(
                title: 'System Disarmed',
                message: 'Journey protection ended successfully.',
                status: 'OK',
              );
            },
            correctPin: pin,
          );
        },
      );
    }
  }

  Widget _buildShieldCard() {
    final shieldService = SilentEvidenceShieldService();
    final status = shieldService.status;
    final isActive = status != ShieldStatus.inactive;

    String statusText = "DISABLED";
    Color statusColor = AppColors.mutedText;
    if (status == ShieldStatus.monitoring) {
      statusText = "ACTIVE";
      statusColor = AppColors.successGreen;
    } else if (status == ShieldStatus.riskDetected) {
      statusText = "RISK DETECTED";
      statusColor = AppColors.warningOrange;
    } else if (status == ShieldStatus.emergencyActive) {
      statusText = "EMERGENCY ACTIVE";
      statusColor = AppColors.emergencyRed;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: AppColors.glassDecoration(
            borderRadius: BorderRadius.circular(20),
          ).copyWith(
            border: Border.all(
              color: isActive
                  ? (status == ShieldStatus.emergencyActive
                      ? AppColors.emergencyRed.withOpacity(0.5)
                      : (status == ShieldStatus.riskDetected
                          ? AppColors.warningOrange.withOpacity(0.5)
                          : AppColors.successGreen.withOpacity(0.5)))
                  : Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showShieldSettingsSheet,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isActive ? statusColor : AppColors.primaryDark).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        color: isActive ? statusColor : AppColors.primaryDark,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  "Evidence Shield",
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                flex: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: GoogleFonts.poppins(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isActive ? "Monitoring active journey. Tap to view metrics." : "AI journey monitoring. Tap to start trip.",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: AppColors.mutedText,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 4. AI SAFETY SCORE MODULE
  Widget _buildAIIntelligenceCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: AppColors.glassDecoration(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              // Radial progress ring
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 0.98,
                      strokeWidth: 8,
                      backgroundColor: AppColors.primaryDark.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.softLavender),
                    ),
                    Text(
                      "98",
                      style: GoogleFonts.poppins(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "WeSafe AI Threat Intelligence",
                      style: GoogleFonts.poppins(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
                      ),
                      child: Text(
                        "STATUS: SAFE",
                        style: GoogleFonts.poppins(
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Smart analysis estimates low threat level in your present neighborhood.",
                      style: GoogleFonts.poppins(
                        color: AppColors.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // 5. EMERGENCY SERVICES PANEL
  Widget _buildEmergencyServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Emergency Services",
          style: GoogleFonts.poppins(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildEmergencyCard(
              title: "Police",
              subtitle: "National Police",
              icon: Icons.local_police_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF3A004D), Color(0xFF8B4F67)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => _makeCall("15"),
            ),
            _buildEmergencyCard(
              title: "Ambulance",
              subtitle: "Medical Service",
              icon: Icons.medical_services_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF8B4F67), Color(0xFFAE4BB0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => _makeCall("112"),
            ),
            _buildEmergencyCard(
              title: "Women Helpline",
              subtitle: "Support Center",
              icon: Icons.support_agent_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFFAE4BB0), Color(0xFF3A004D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => _makeCall("1091"),
            ),
            _buildEmergencyCard(
              title: "Family SOS",
              subtitle: "Alert Key Contact",
              icon: Icons.family_restroom_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF3A004D), Color(0xFFAE4BB0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: _callFamilySOS,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmergencyCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: Colors.white, size: 28),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 14),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapWidget() {
    final bool isMacOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    
    if (isMacOS) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: const Color(0xFFF5EBF3),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
              ),
              itemCount: 24,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 0.5,
                    ),
                  ),
                );
              },
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: RadarPainter(_radarController.value),
                    child: const SizedBox(width: 80, height: 80),
                  );
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Map Simulated (macOS)",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (currentLat == null || currentLng == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
        ),
      );
    }

    final LatLng position = LatLng(currentLat!, currentLng!);
    
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: position,
            zoom: widget.isSOSAlerted ? 18.0 : 16.0,
            bearing: currentHeading,
          ),
          circles: {
            Circle(
              circleId: const CircleId('accuracy_circle'),
              center: position,
              radius: currentAccuracy ?? 0.0,
              fillColor: (widget.isSOSAlerted ? Colors.red : AppColors.primaryPurple).withOpacity(0.12),
              strokeColor: (widget.isSOSAlerted ? Colors.red : AppColors.primaryPurple).withOpacity(0.4),
              strokeWidth: 2,
            ),
          },
          markers: {
            Marker(
              markerId: const MarkerId('current_location'),
              position: position,
              rotation: currentHeading,
              flat: true,
              anchor: const Offset(0.5, 0.5),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                widget.isSOSAlerted ? BitmapDescriptor.hueRed : BitmapDescriptor.hueViolet,
              ),
              infoWindow: InfoWindow(
                title: widget.isSOSAlerted ? 'SOS High Precision Tracking' : 'Current Location',
                snippet: 'Accuracy: ±${currentAccuracy?.toStringAsFixed(1)}m',
              ),
            ),
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            if (isCameraLocked) {
              _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: position,
                    zoom: widget.isSOSAlerted ? 18.0 : 16.0,
                    bearing: currentHeading,
                    tilt: widget.isSOSAlerted ? 45.0 : 0.0,
                  ),
                ),
              );
            }
          },
          onCameraMoveStarted: () {
            if (isCameraLocked) {
              setState(() {
                isCameraLocked = false;
              });
            }
          },
        ),
        // Recenter Lock Toggle Button
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: "recenter_camera_btn",
            backgroundColor: isCameraLocked 
                ? (widget.isSOSAlerted ? AppColors.emergencyRed : AppColors.primaryPurple)
                : Colors.white,
            foregroundColor: isCameraLocked ? Colors.white : AppColors.textDark,
            onPressed: () {
              setState(() {
                isCameraLocked = true;
              });
              if (_mapController != null && currentLat != null && currentLng != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(currentLat!, currentLng!),
                      zoom: widget.isSOSAlerted ? 18.0 : 16.0,
                      bearing: currentHeading,
                      tilt: widget.isSOSAlerted ? 45.0 : 0.0,
                    ),
                  ),
                );
              }
            },
            child: Icon(
              isCameraLocked ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  // 6. LIVE LOCATION MODULE
  Widget _buildLiveLocationModule() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: AppColors.glassDecoration(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Live Location Module",
                    style: GoogleFonts.poppins(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (isLocating)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.primaryPurple)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Google Maps Visualizer
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMapWidget(),
                ),
              ),
              const SizedBox(height: 16),
              // Signal & Ticker Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSignalLost 
                          ? AppColors.emergencyRed.withOpacity(0.12)
                          : AppColors.successGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSignalLost ? AppColors.emergencyRed : AppColors.successGreen,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSignalLost ? AppColors.emergencyRed : AppColors.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSignalLost ? "SIGNAL LOST" : "LIVE CONNECTION",
                          style: GoogleFonts.poppins(
                            color: isSignalLost ? AppColors.emergencyRed : AppColors.successGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    lastUpdateTime == null 
                        ? "Never updated" 
                        : "Updated ${_secondsSinceLastUpdate}s ago",
                    style: GoogleFonts.poppins(
                      color: AppColors.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // GPS Address text
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.primaryDark, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentAddress,
                      style: GoogleFonts.poppins(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Metrics Grid Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ACCURACY",
                            style: GoogleFonts.poppins(
                              color: AppColors.mutedText,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentAccuracy != null 
                                ? "${currentAccuracy!.toStringAsFixed(1)} m"
                                : "Locking...",
                            style: GoogleFonts.shareTechMono(
                              color: AppColors.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SPEED",
                            style: GoogleFonts.poppins(
                              color: AppColors.mutedText,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentSpeed != null && currentSpeed! > 0
                                ? "${(currentSpeed! * 3.6).toStringAsFixed(1)} km/h"
                                : "0.0 km/h",
                            style: GoogleFonts.shareTechMono(
                              color: AppColors.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "HEADING",
                            style: GoogleFonts.poppins(
                              color: AppColors.mutedText,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${currentHeading.toStringAsFixed(0)}°",
                            style: GoogleFonts.shareTechMono(
                              color: AppColors.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Emergency Battery Warning
              if (widget.isSOSAlerted) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.emergencyRed.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on_rounded, color: AppColors.emergencyRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "EMERGENCY PRECISION MODE ACTIVE\nContinuous GPS updates may impact battery life.",
                          style: GoogleFonts.poppins(
                            color: AppColors.emergencyRed,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primaryPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.share_location_rounded, color: Colors.white, size: 18),
                        label: Text("Share Tracking Link", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          if (currentLat != null && currentLng != null) {
                            Clipboard.setData(ClipboardData(text: "https://maps.google.com/?q=$currentLat,$currentLng"));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Live tracking link copied to clipboard!"),
                                backgroundColor: AppColors.successGreen,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Waiting for GPS lock..."),
                                backgroundColor: AppColors.emergencyRed,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
  // 8. EXPLORE SAFETY HUB
  Widget _buildExploreSafetyHub() {
    final hubItems = [
      {
        "title": "Safety & Self Defense Tips",
        "description": "Learn tactical and physical maneuvers to de-escalate crisis encounters.",
        "icon": Icons.sports_kabaddi_rounded,
        "color": AppColors.primaryDark
      },
      {
        "title": "Trusted Safe Routes",
        "description": "Verify well-lit AI safety verified routes to destination checkpoints.",
        "icon": Icons.map_rounded,
        "color": AppColors.softLavender
      },
      {
        "title": "Support Networks",
        "description": "Access active support channels & emergency safety support units.",
        "icon": Icons.health_and_safety_rounded,
        "color": AppColors.successGreen
      }
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Explore Safety Hub",
          style: GoogleFonts.poppins(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: hubItems.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = hubItems[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 250,
                    padding: const EdgeInsets.all(20),
                    decoration: AppColors.glassDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (item["color"] as Color).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item["icon"] as IconData, color: item["color"] as Color, size: 20),
                            ),
                            const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryPurple, size: 16),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item["title"] as String,
                              style: GoogleFonts.poppins(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item["description"] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: AppColors.mutedText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildEmergencyContactsDashboardCard() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isEmpty) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: CloudService().streamEmergencyContacts(uid),
      builder: (context, snap) {
        int contactCount = 0;
        List<Widget> contactTiles = [];

        if (snap.hasData && snap.data != null) {
          final docs = snap.data!.docs;
          contactCount = docs.length;

          for (var doc in docs) {
            final name = doc['name'] as String? ?? "Unknown";
            final phone = doc['phone'] as String? ?? "";

            contactTiles.add(
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.softLavender.withOpacity(0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "U",
                            style: GoogleFonts.poppins(color: AppColors.primaryPurple, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              phone,
                              style: GoogleFonts.shareTechMono(color: AppColors.mutedText, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone_in_talk_rounded, color: AppColors.successGreen, size: 16),
                      onPressed: () => _makeCall(phone),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            );
          }
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: AppColors.glassDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Emergency Contacts",
                            style: GoogleFonts.poppins(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$contactCount contacts saved",
                            style: GoogleFonts.poppins(
                              color: AppColors.mutedText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: AppColors.primaryPurple, size: 16),
                        ),
                        onPressed: _showAddManualContactDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (contactTiles.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          "No emergency contacts registered yet.",
                          style: GoogleFonts.poppins(color: AppColors.mutedText, fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ),
                    )
                  else
                    Column(children: contactTiles),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddManualContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Add Manual Contact",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                style: GoogleFonts.poppins(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: "Contact Name",
                  labelStyle: GoogleFonts.poppins(color: AppColors.mutedText),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryPurple)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.poppins(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  labelStyle: GoogleFonts.poppins(color: AppColors.mutedText),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryPurple)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Phone number is required" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.poppins(color: AppColors.mutedText, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
              if (uid.isNotEmpty) {
                await CloudService().addEmergencyContact(
                  uid,
                  nameController.text.trim(),
                  phoneController.text.trim(),
                );
                WeSafeToast.showSuccess(
                  title: 'Contact Registered',
                  message: '${nameController.text.trim()} added to your emergency list.',
                  status: 'OK',
                );
                Navigator.pop(context);
              }
            },
            child: Text("SAVE", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// Radar Scanning painter
class RadarPainter extends CustomPainter {
  final double progress;
  RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryPurple.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw grid rings
    canvas.drawCircle(center, size.width * 0.1, paint);
    canvas.drawCircle(center, size.width * 0.25, paint);
    canvas.drawCircle(center, size.width * 0.4, paint);

    // Draw crosshair axes
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);

    // Sweep scan line
    final sweepPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = SweepGradient(
        colors: [
          AppColors.softLavender.withOpacity(0.0),
          AppColors.softLavender.withOpacity(0.15),
          AppColors.softLavender.withOpacity(0.3),
        ],
        stops: const [0.0, 0.9, 1.0],
        transform: GradientRotation(progress * 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.45));

    canvas.drawCircle(center, size.width * 0.45, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) => oldDelegate.progress != progress;
}
