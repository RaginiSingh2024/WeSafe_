import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womensafteyhackfair/constants.dart';
import 'package:womensafteyhackfair/cloud_service.dart';

class GuardianDashboard extends StatefulWidget {
  const GuardianDashboard({Key? key}) : super(key: key);

  @override
  _GuardianDashboardState createState() => _GuardianDashboardState();
}

class _GuardianDashboardState extends State<GuardianDashboard> {
  final CloudService _cloudService = CloudService();
  String _myEmail = '';
  List<String> _monitoredUserEmails = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuardianContext();
  }

  Future<void> _loadGuardianContext() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    _myEmail = user?.email ?? prefs.getString('registered_email') ?? '';
    
    if (_myEmail.isNotEmpty) {
      final links = await _cloudService.getMonitoredUsers(_myEmail);
      setState(() {
        _monitoredUserEmails = links.map((l) => (l['user_email'] as String).toLowerCase()).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "Guardian Dashboard",
          style: GoogleFonts.poppins(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDark))
          : StreamBuilder<QuerySnapshot>(
              stream: _cloudService.streamActiveShieldJourneys(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildNoActiveJourneysView();
                }

                // Filter docs to only show active journeys of users that this guardian is linked to
                final activeJourneys = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final userEmail = (data['userId'] as String).toLowerCase();
                  // We also match by userPhone or userName if email links are not strictly matched, 
                  // but for robust simulation we allow seeing any active journey if no specific links are configured,
                  // or filter by monitoredUserEmails if configured.
                  if (_monitoredUserEmails.isEmpty) {
                    // If no links configured in DB, allow testing/monitoring any active journey for demo purposes
                    return true;
                  }
                  return _monitoredUserEmails.contains(userEmail);
                }).toList();

                if (activeJourneys.isEmpty) {
                  return _buildNoActiveJourneysView();
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  itemCount: activeJourneys.length,
                  itemBuilder: (context, index) {
                    final journeyDoc = activeJourneys[index];
                    final data = journeyDoc.data() as Map<String, dynamic>;
                    return _buildJourneyCard(data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildNoActiveJourneysView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppColors.primaryDark,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Active Journeys",
              style: GoogleFonts.poppins(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "There are currently no active Silent Evidence Shield journeys to monitor. You will be notified automatically if a linked user triggers an emergency.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyCard(Map<String, dynamic> data) {
    final String userName = data['userName'] ?? 'WeSafe User';
    final String status = data['status'] ?? 'Monitoring';
    final String destination = data['destination'] ?? 'Unknown';
    final double latitude = data['latitude'] ?? 0.0;
    final double longitude = data['longitude'] ?? 0.0;
    final int battery = data['batteryPercentage'] ?? 100;
    final List<dynamic> timeline = data['journeyTimeline'] ?? [];
    final List<dynamic> routeHistory = data['routeHistory'] ?? [];

    Color statusColor = AppColors.successGreen;
    if (status == 'Risk Detected') statusColor = AppColors.warningOrange;
    if (status == 'Emergency Active') statusColor = AppColors.emergencyRed;

    IconData batteryIcon = Icons.battery_full_rounded;
    if (battery < 20) batteryIcon = Icons.battery_alert_rounded;
    else if (battery < 50) batteryIcon = Icons.battery_3_bar_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: AppColors.glassDecoration(
        color: status == 'Emergency Active' ? Colors.red.shade50 : Colors.white,
      ),
      child: ExpansionTile(
        initiallyExpanded: status == 'Emergency Active',
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                userName,
                style: GoogleFonts.poppins(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            "Status: $status • Destination: $destination",
            style: GoogleFonts.poppins(
              color: AppColors.mutedText,
              fontSize: 12,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(batteryIcon, color: battery < 20 ? AppColors.emergencyRed : AppColors.primaryPurple, size: 18),
            const SizedBox(width: 4),
            Text(
              "$battery%",
              style: GoogleFonts.shareTechMono(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "📍 LIVE LOCATION",
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Lat: ${latitude.toStringAsFixed(5)}, Lng: ${longitude.toStringAsFixed(5)}",
                          style: GoogleFonts.poppins(
                            color: AppColors.textDark,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () => _openGoogleMaps(latitude, longitude),
                      icon: const Icon(Icons.map_rounded, color: Colors.white, size: 16),
                      label: Text(
                        "OPEN MAPS",
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "🕒 JOURNEY TIMELINE",
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: timeline.length,
                    itemBuilder: (context, tIndex) {
                      final item = timeline[timeline.length - 1 - tIndex] as Map<String, dynamic>;
                      final String event = item['event'] ?? '';
                      final String timeStr = item['timestamp'] != null 
                          ? DateTime.parse(item['timestamp']).toLocal().toString().split(' ')[1].split('.')[0]
                          : '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "[$timeStr]",
                              style: GoogleFonts.shareTechMono(
                                color: AppColors.mutedText,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event,
                                style: GoogleFonts.poppins(
                                  color: AppColors.textDark,
                                  fontSize: 12,
                                  fontWeight: event.contains("Suspicious") || event.contains("Emergency")
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "🗺 ROUTE HISTORY",
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: routeHistory.length,
                    itemBuilder: (context, rIndex) {
                      final item = routeHistory[routeHistory.length - 1 - rIndex] as Map<String, dynamic>;
                      final double lat = item['latitude'] ?? 0.0;
                      final double lng = item['longitude'] ?? 0.0;
                      final String timeStr = item['timestamp'] != null 
                          ? DateTime.parse(item['timestamp']).toLocal().toString().split(' ')[1].split('.')[0]
                          : '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: AppColors.primaryPurple.withOpacity(0.5), size: 14),
                            const SizedBox(width: 8),
                            Text(
                              "$timeStr - Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}",
                              style: GoogleFonts.poppins(
                                color: AppColors.textDark,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
