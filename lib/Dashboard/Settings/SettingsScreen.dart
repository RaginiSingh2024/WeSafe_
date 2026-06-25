import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womensafteyhackfair/Dashboard/Settings/About.dart';
import 'package:womensafteyhackfair/Dashboard/Settings/ChangePin.dart';
import 'package:womensafteyhackfair/Dashboard/Auth/LoginScreen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:womensafteyhackfair/constants.dart';
import 'package:womensafteyhackfair/voice_detection_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool switchValue = false;
  final VoiceDetectionService _voiceService = VoiceDetectionService();
  Stream<QuerySnapshot>? _alertHistoryStream;

  Future<int> checkPIN() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int pin = (prefs.getInt('pin') ?? -1111);
    return pin;
  }

  void _initAlertHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String phone = prefs.getString('registered_phone') ?? '';
    
    // Fallback to Firestore user profile if not in SharedPreferences
    if (phone.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.email!.toLowerCase())
              .get();
          if (userDoc.exists) {
            phone = userDoc.data()?['phone'] ?? '';
            if (phone.isNotEmpty) {
              await prefs.setString('registered_phone', phone);
            }
          }
        } catch (e) {
          debugPrint("Error fetching user phone from Firestore: $e");
        }
      }
    }

    if (phone.isNotEmpty && mounted) {
      setState(() {
        _alertHistoryStream = FirebaseFirestore.instance
            .collection('sos_alerts')
            .where('phone_number', isEqualTo: phone)
            .limit(50)
            .snapshots();
      });
    } else if (mounted) {
      // If we still don't have a phone number, stream all active/past alerts as a general fallback
      setState(() {
        _alertHistoryStream = FirebaseFirestore.instance
            .collection('sos_alerts')
            .limit(50)
            .snapshots();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    checkService();
    _voiceService.addListener(_onVoiceServiceStateChanged);
    _initAlertHistory();
  }

  @override
  void dispose() {
    _voiceService.removeListener(_onVoiceServiceStateChanged);
    super.dispose();
  }

  void _onVoiceServiceStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: canPop
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppColors.primaryDark,
                ),
                onPressed: () {
                  Navigator.pop(context);
                })
            : null,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "GUARDIAN PARAMETERS",
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Settings",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),

          // SOS PIN Configuration
          FutureBuilder<int>(
            future: checkPIN(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final pin = snapshot.data;
                final isNotSet = pin == -1111;

                return Container(
                  decoration: AppColors.glassDecoration(),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChangePinScreen(pin: pin),
                          ),
                        ).then((_) => setState(() {}));
                      },
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryPurple.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.lock_rounded, color: AppColors.primaryPurple, size: 20),
                      ),
                      title: Text(
                        isNotSet ? "Create SOS PIN" : "Change SOS PIN",
                        style: GoogleFonts.poppins(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "SOS PIN is required to switch OFF the SOS alert.",
                          style: GoogleFonts.poppins(color: AppColors.mutedText, fontSize: 12),
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: isNotSet ? AppColors.emergency : AppColors.textDark.withOpacity(0.3),
                        size: 16,
                      ),
                    ),
                  ),
                );
              } else {
                return const SizedBox();
              }
            },
          ),
          const SizedBox(height: 24),

          // Section Header: Notifications & Background Features
          Row(
            children: [
              Text(
                "BACKGROUND ENGINE",
                style: GoogleFonts.poppins(
                  color: AppColors.primaryPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(color: AppColors.textDark.withOpacity(0.1)),
              )
            ],
          ),
          const SizedBox(height: 16),


          // Panic Voice Detection Card
          Container(
            decoration: AppColors.glassDecoration(),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  activeColor: AppColors.softLavender,
                  activeTrackColor: AppColors.primaryDark.withOpacity(0.25),
                  inactiveThumbColor: AppColors.mutedText,
                  inactiveTrackColor: AppColors.textDark.withOpacity(0.1),
                  value: _voiceService.isEnabled,
                  onChanged: (val) {
                    setState(() {
                      _voiceService.setEnabled(val);
                    });
                  },
                  secondary: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryDark.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.mic_none_rounded, color: AppColors.primaryDark, size: 20),
                  ),
                  title: Text(
                    "Panic Voice Detection",
                    style: GoogleFonts.poppins(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "Listen for distress keywords to trigger SOS.",
                      style: GoogleFonts.poppins(color: AppColors.mutedText, fontSize: 12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Automatically monitors voice input for custom/built-in panic words when active. Set your response type to Silent Protection (sends SMS alerts) or Active Emergency (screech alarms and flashing light).",
                        style: GoogleFonts.poppins(
                          color: AppColors.mutedText,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Sensitivity slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Voice Sensitivity",
                            style: GoogleFonts.poppins(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            "${(_voiceService.sensitivity * 100).toInt()}%",
                            style: GoogleFonts.shareTechMono(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _voiceService.sensitivity,
                        activeColor: AppColors.softLavender,
                        inactiveColor: AppColors.mutedBlushLavender.withOpacity(0.4),
                        onChanged: (val) {
                          setState(() {
                            _voiceService.setSensitivity(val);
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      // Response Mode Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          "Stealth Protection (Silent)",
                          style: GoogleFonts.poppins(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        value: _voiceService.isSilentMode,
                        activeColor: AppColors.softLavender,
                        onChanged: (val) {
                          setState(() {
                            _voiceService.setSilentMode(val);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildAlertTimeline(),
          const SizedBox(height: 24),

          // Section Header: Application Info
          Row(
            children: [
              Text(
                "APPLICATION SETTINGS",
                style: GoogleFonts.poppins(
                  color: AppColors.primaryPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(color: AppColors.textDark.withOpacity(0.1)),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Action Options list
          Container(
            decoration: AppColors.glassDecoration(),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AboutUs()),
                      );
                    },
                    leading: const Icon(Icons.info_outline_rounded, color: AppColors.primaryDark),
                    title: Text(
                      "About Us",
                      style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.w600),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textDark.withOpacity(0.3), size: 14),
                  ),
                  Divider(color: AppColors.textDark.withOpacity(0.08), height: 1, indent: 20, endIndent: 20),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: const Icon(Icons.share_rounded, color: AppColors.primaryDark),
                    title: Text(
                      "Share WeSafe",
                      style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.w600),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textDark.withOpacity(0.3), size: 14),
                    onTap: () {
                      Fluttertoast.showToast(msg: "App sharing link copied to clipboard!");
                    },
                  ),
                  Divider(color: AppColors.textDark.withOpacity(0.08), height: 1, indent: 20, endIndent: 20),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    onTap: () async {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await prefs.setBool("is_logged_in", false);
  
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
  
                      Fluttertoast.showToast(
                        msg: "Logged out successfully!",
                        backgroundColor: AppColors.success,
                      );
                    },
                    leading: const Icon(Icons.logout_rounded, color: AppColors.emergency),
                    title: Text(
                      "Log Out",
                      style: GoogleFonts.poppins(
                        color: AppColors.emergency,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textDark.withOpacity(0.3), size: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<bool> checkService() async {
    if (kIsWeb) return false;
    bool running = await FlutterBackgroundService().isRunning();
    setState(() {
      switchValue = running;
    });
    return running;
  }

  void controllSafeShake(bool val) async {
    if (kIsWeb) return;
    if (val) {
      await FlutterBackgroundService().startService();
    } else {
      FlutterBackgroundService().invoke(
        "action",
        {"action": "stopService"},
      );
    }
  }

  String _formatRelativeTime(dynamic createdAt) {
    if (createdAt == null) return "Just now";
    DateTime dateTime;
    if (createdAt is Timestamp) {
      dateTime = createdAt.toDate();
    } else if (createdAt is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else {
      return "Just now";
    }

    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) {
      return "Just now";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes} mins ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours} hours ago";
    } else if (diff.inDays == 1) {
      return "Yesterday";
    } else {
      return "${diff.inDays} days ago";
    }
  }

  Widget _buildTimelineNodeForDoc(DocumentSnapshot doc, bool isFirst, bool isLast) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final triggerType = data['trigger_type'] as String? ?? 'unknown';
    final keyword = data['trigger_keyword'] as String? ?? '';
    final createdAt = data['created_at'];

    String title = "Security Alert";
    String subtitle = "Alert triggered successfully.";
    Color color = AppColors.softLavender;

    if (triggerType == 'manual') {
      title = "Manual SOS Alert Triggered";
      subtitle = "SOS emergency SMS sent to all active contacts.";
      color = AppColors.emergency;
    } else if (triggerType == 'voice') {
      title = "Safe Word Detected";
      subtitle = "Detected keyword '$keyword' with high confidence.";
      color = AppColors.warningOrange;
    } else if (triggerType == 'shake_alert') {
      title = "Shake Alert Triggered";
      subtitle = "Emergency alert sent via shake motion detection.";
      color = AppColors.emergency;
    } else if (triggerType == 'wearable') {
      title = "Wearable Device SOS Triggered";
      subtitle = keyword.isNotEmpty ? keyword : "SOS alert triggered from active wearable.";
      color = AppColors.emergency;
    } else if (triggerType == 'silent_shield' || triggerType == 'geofence') {
      title = "Geo-Fence Safety Breach";
      subtitle = "Exit verified secure route corridor.";
      color = AppColors.softLavender;
    } else {
      title = "Security Alert Triggered";
      subtitle = "WeSafe alert initialized (Type: $triggerType).";
      color = AppColors.softLavender;
    }

    final timeStr = _formatRelativeTime(createdAt);

    return _buildTimelineNode(
      title: title,
      subtitle: subtitle,
      time: timeStr,
      color: color,
      isFirst: isFirst,
      isLast: isLast,
    );
  }

  Widget _buildAlertTimeline() {
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
              Text(
                "Alert History",
                style: GoogleFonts.poppins(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              if (_alertHistoryStream == null)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                  ),
                )
              else
                StreamBuilder<QuerySnapshot>(
                  stream: _alertHistoryStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      debugPrint("Firestore alert history stream error: ${snapshot.error}");
                      return Text(
                        "Error loading alert history",
                        style: GoogleFonts.poppins(color: AppColors.emergency, fontSize: 12),
                      );
                    }
                    final docs = List<DocumentSnapshot>.from(snapshot.data?.docs ?? []);
                    
                    // Sort in memory to avoid Firebase composite index requirement
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

                    final displayedDocs = docs.length > 10 ? docs.sublist(0, 10) : docs;

                    if (displayedDocs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.shield_outlined,
                                  color: AppColors.successGreen,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "All Secure",
                                style: GoogleFonts.poppins(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "No security alerts have been triggered recently.",
                                style: GoogleFonts.poppins(
                                  color: AppColors.mutedText,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedDocs.length,
                      itemBuilder: (context, index) {
                        return _buildTimelineNodeForDoc(
                          displayedDocs[index],
                          index == 0,
                          index == displayedDocs.length - 1,
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineNode({
    required String title,
    required String subtitle,
    required String time,
    required Color color,
    required bool isFirst,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 12,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!(isFirst && isLast))
                  Positioned(
                    top: isFirst ? 10 : 0,
                    bottom: isLast ? null : 0,
                    height: isLast ? 10 : null,
                    child: Container(
                      width: 2,
                      color: AppColors.mutedBlushLavender.withOpacity(0.5),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        color: AppColors.primaryPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          )
        ],
      ),
    );
  }
}
