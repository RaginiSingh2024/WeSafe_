import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:womensafteyhackfair/Dashboard/Settings/AboutCard.dart';
import 'package:womensafteyhackfair/Dashboard/ContactScreens/MyContacts.dart';
import 'package:womensafteyhackfair/constants.dart';

class AboutUs extends StatefulWidget {
  const AboutUs({Key? key}) : super(key: key);

  @override
  State<AboutUs> createState() => _AboutUsState();
}

class _AboutUsState extends State<AboutUs> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isTablet = mediaQuery.size.width > 600;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.lightBackground, AppColors.mutedBlushLavender],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            "About WeSafe",
            style: GoogleFonts.poppins(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.4),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppColors.primaryDark,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.4),
                child: IconButton(
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primaryDark,
                    size: 18,
                  ),
                  onPressed: () => _showLicences(context),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Glassmorphic ambient backdrop spots
            Positioned(
              top: 80,
              left: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.softLavender.withOpacity(0.15),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPurple.withOpacity(0.12),
                ),
              ),
            ),
            Positioned.fill(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                children: [
                  // 1. HERO SECTION
                  const FadeInSlide(
                    delay: Duration(milliseconds: 0),
                    child: HeroSection(),
                  ),
                  const SizedBox(height: 32),

                  // 2. PROBLEM STATEMENT SECTION
                  FadeInSlide(
                    delay: const Duration(milliseconds: 150),
                    child: _buildProblemSection(isTablet),
                  ),
                  const SizedBox(height: 32),

                  // 3. OUR SOLUTION SECTION
                  FadeInSlide(
                    delay: const Duration(milliseconds: 250),
                    child: _buildSolutionSection(),
                  ),
                  const SizedBox(height: 32),

                  // 4. HOW IT WORKS SECTION
                  FadeInSlide(
                    delay: const Duration(milliseconds: 350),
                    child: _buildHowItWorksSection(),
                  ),
                  const SizedBox(height: 32),

                  // 5. IMPACT & VISION SECTION
                  FadeInSlide(
                    delay: const Duration(milliseconds: 450),
                    child: _buildStatsSection(isTablet),
                  ),
                  const SizedBox(height: 32),

                  // 6. WHY WESAFE SECTION
                  FadeInSlide(
                    delay: const Duration(milliseconds: 550),
                    child: _buildWhyWeSafeSection(),
                  ),
                  const SizedBox(height: 32),

                  // 7. TEAM / BUILDERS SECTION
                  FadeInSlide(
                    delay: const Duration(milliseconds: 650),
                    child: _buildTeamSection(),
                  ),
                  const SizedBox(height: 32),

                  // 8. TRUST & SAFETY SECTION
                  FadeInSlide(
                    delay: const Duration(milliseconds: 750),
                    child: _buildTrustSafetySection(),
                  ),
                  const SizedBox(height: 36),

                  // 9. CALL TO ACTION SECTION
                  FadeInSlide(
                    delay: const Duration(milliseconds: 850),
                    child: _buildCTASection(context),
                  ),
                  const SizedBox(height: 28),

                  // Licences & Open Source
                  FadeInSlide(
                    delay: const Duration(milliseconds: 950),
                    child: _buildLicenceTile(context),
                  ),
                  const SizedBox(height: 40),

                  // Footer
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          indent: 10,
                          endIndent: 10,
                          color: AppColors.textDark.withOpacity(0.1),
                        ),
                      ),
                      Text(
                        "© 2026 WeSafe, All rights reserved.",
                        style: GoogleFonts.poppins(
                          color: AppColors.mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          indent: 10,
                          endIndent: 10,
                          color: AppColors.textDark.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. PROBLEM STATEMENT SECTION
  Widget _buildProblemSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "The Safety Crisis",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Traditional safety systems are failing when every second count.",
          style: GoogleFonts.poppins(
            color: AppColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isTablet ? 4 : 2,
          childAspectRatio: 1.05,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildProblemCard(
              Icons.warning_amber_rounded,
              "Threat Isolation",
              "Personal vulnerabilities persist in isolated moments.",
              AppColors.emergencyRed,
            ),
            _buildProblemCard(
              Icons.hourglass_disabled_rounded,
              "Response Delay",
              "Critical dispatch lags average several minutes.",
              AppColors.warningOrange,
            ),
            _buildProblemCard(
              Icons.do_not_disturb_on_rounded,
              "No Instant Access",
              "Inability to trigger alert when phone is out of reach.",
              AppColors.primaryPurple,
            ),
            _buildProblemCard(
              Icons.lock_rounded,
              "Restricted Hands",
              "Physical restraint stops manual dialing.",
              AppColors.primaryDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProblemCard(IconData icon, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              desc,
              style: GoogleFonts.poppins(
                color: AppColors.mutedText,
                fontSize: 10,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 3. OUR SOLUTION SECTION
  Widget _buildSolutionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "How WeSafe Protects You",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Built with premium voice-first technologies for zero-barrier operation.",
          style: GoogleFonts.poppins(
            color: AppColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        AboutCard(
          asset: "",
          icon: Icons.keyboard_voice_rounded,
          title: "Safe Word Detection",
          subtitle: "Hands-Free Activated",
          desc: "Speak your custom safe word to trigger SOS, even while your phone is locked or slipped away in a pocket.",
          sizeFactor: 0,
        ),
        AboutCard(
          asset: "",
          icon: Icons.psychology_rounded,
          title: "Panic Cues Classifier",
          subtitle: "AI-Powered Analysis",
          desc: "Our neural modules running locally on-device evaluate distress vocalizations, detecting fear markers instantly.",
          sizeFactor: 0,
          glowColor: AppColors.softLavender,
        ),
        AboutCard(
          asset: "",
          icon: Icons.notifications_active_rounded,
          title: "Instant SOS Alerts",
          subtitle: "Automated Dispatch",
          desc: "Bypasses standard dialers to send secure SOS distress messages with precise tracking to emergency contacts.",
          sizeFactor: 0,
          glowColor: AppColors.emergencyRed,
        ),
        AboutCard(
          asset: "",
          icon: Icons.my_location_rounded,
          title: "Live Location Broadcast",
          subtitle: "Guardian Network",
          desc: "Shares continuous high-accuracy coordinate maps with your guardians, updating seamlessly under low-power modes.",
          sizeFactor: 0,
        ),
      ],
    );
  }

  // 4. HOW IT WORKS SECTION
  Widget _buildHowItWorksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "The Guardian Cycle",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "A step-by-step loop prioritizing speed, safety, and privacy.",
          style: GoogleFonts.poppins(
            color: AppColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        _buildTimelineStep(
          "1",
          "Voice Watchers Active",
          "Background listening loop monitors audio streams strictly offline on edge hardware.",
          Icons.lens_blur_rounded,
          false,
        ),
        _buildTimelineStep(
          "2",
          "Panic Code Word Spoken",
          "Speaking your custom keyword wakes WeSafe immediately.",
          Icons.spatial_audio_off_rounded,
          false,
        ),
        _buildTimelineStep(
          "3",
          "Local Neural Classification",
          "Local models check panic signatures and trigger validation protocols instantly.",
          Icons.analytics_outlined,
          false,
        ),
        _buildTimelineStep(
          "4",
          "Automatic SOS Wakeup",
          "The core dispatch module wakes up and gathers telemetry in milliseconds.",
          Icons.offline_bolt_rounded,
          false,
        ),
        _buildTimelineStep(
          "5",
          "Distress Packet Dispatched",
          "Sends real-time coordinates, audio stream details, and alerts to active emergency contacts.",
          Icons.send_rounded,
          true,
        ),
      ],
    );
  }

  Widget _buildTimelineStep(
    String stepNum,
    String title,
    String description,
    IconData icon,
    bool isLast,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryDark,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    stepNum,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.0,
                    color: AppColors.primaryPurple.withOpacity(0.35),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: AppColors.glassDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.primaryPurple, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.poppins(
                            color: AppColors.mutedText,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. IMPACT & VISION SECTION
  Widget _buildStatsSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Safety in Numbers",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Providing trusted protection and immediate assistance networks.",
          style: GoogleFonts.poppins(
            color: AppColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isTablet ? 4 : 2,
          childAspectRatio: 1.35,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildStatCard("99.9%", "Engine Uptime", Icons.cloud_done_rounded, AppColors.successGreen),
            _buildStatCard("< 3s", "Dispatch Rate", Icons.bolt_rounded, AppColors.warningOrange),
            _buildStatCard("10k+", "Users Protected", Icons.people_alt_rounded, AppColors.softLavender),
            _buildStatCard("0%", "Data Shared", Icons.lock_outline_rounded, AppColors.primaryPurple),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              AnimatedCounter(
                endValue: _parseValue(value),
                suffix: _parseSuffix(value),
                prefix: _parsePrefix(value),
                decimals: value.contains('.') ? 1 : 0,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: AppColors.mutedText,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  double _parseValue(String val) {
    final clean = val.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  String _parseSuffix(String val) {
    return val.replaceAll(RegExp(r'[0-9.]'), '');
  }

  String _parsePrefix(String val) {
    if (val.startsWith('<')) return '< ';
    return '';
  }

  // 6. WHY WESAFE SECTION
  Widget _buildWhyWeSafeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Why Choose WeSafe?",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: AppColors.glassDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Other Systems",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildComparisonItem(Icons.close_rounded, "Requires unlocking", Colors.red),
                    _buildComparisonItem(Icons.close_rounded, "Manual keypad calls", Colors.red),
                    _buildComparisonItem(Icons.close_rounded, "Panic delay", Colors.red),
                    _buildComparisonItem(Icons.close_rounded, "No ambient records", Colors.red),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.successGreen.withOpacity(0.45),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.successGreen.withOpacity(0.06),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "WeSafe Guardian",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildComparisonItem(Icons.check_rounded, "Runs while locked", AppColors.successGreen),
                    _buildComparisonItem(Icons.check_rounded, "Hands-free triggers", AppColors.successGreen),
                    _buildComparisonItem(Icons.check_rounded, "Instant alerting", AppColors.successGreen),
                    _buildComparisonItem(Icons.check_rounded, "Stealth operations", AppColors.successGreen),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComparisonItem(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: AppColors.textDark,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 7. TEAM / BUILDERS SECTION
  Widget _buildTeamSection() {
    final team = [
      {"name": "Riddhi Zunjarrao", "role": "App Developer"},
      {"name": "Shweta Kadam", "role": "App Developer"},
      {"name": "Ragini Singh", "role": "Reasearcher and business development"},
      {"name": "Sakshi Shingole", "role": "Reasearcher and business development"},
      
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Meet the Builders Behind WeSafe",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 3,
          width: 85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: [AppColors.primaryPurple, AppColors.softLavender, Colors.transparent],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "A multidisciplinary team building AI-powered safety systems that protect people in real-world situations.",
          style: GoogleFonts.poppins(
            color: AppColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "We are engineers, designers, and researchers building systems that respond when humans cannot.",
          style: GoogleFonts.poppins(
            color: AppColors.mutedText.withOpacity(0.85),
            fontSize: 12,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            int crossAxisCount = 2;
            double childAspectRatio = 1.05;

            if (width > 720) {
              crossAxisCount = 3;
              childAspectRatio = 0.95;
            } else if (width > 480) {
              crossAxisCount = 2;
              childAspectRatio = 1.15;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: team.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final member = team[index];
                return FadeInSlide(
                  delay: Duration(milliseconds: 100 + (index * 50)),
                  child: MemberProfileCard(
                    name: member["name"]!,
                    role: member["role"]!,
                    index: index,
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          "Team Pillars & Focus",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTrustBadge("Student-Led Innovation Team"),
            _buildTrustBadge("AI + Security Focused Engineering"),
            _buildTrustBadge("Privacy-First Architecture"),
            _buildTrustBadge("Real-World Safety Impact"),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softLavender.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.softLavender.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.softLavender.withOpacity(0.03),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_rounded, color: AppColors.primaryPurple, size: 12),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: AppColors.primaryPurple,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 8. TRUST & SAFETY SECTION
  Widget _buildTrustSafetySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Trust & Transparency",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppColors.glassDecoration(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_person_rounded, color: AppColors.successGreen, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Your safety shouldn't compromise your privacy.",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTrustBullet(
                Icons.security_rounded,
                "Local Edge Processing",
                "Background voice signals are analyzed strictly local on device. WeSafe never streams your day-to-day conversation to servers.",
              ),
              const Divider(height: 20, color: Colors.white24),
              _buildTrustBullet(
                Icons.vpn_key_rounded,
                "End-to-End Encrypted Feeds",
                "SOS triggers, location tracking coordinates, and system events are safely encrypted in transit.",
              ),
              const Divider(height: 20, color: Colors.white24),
              _buildTrustBullet(
                Icons.privacy_tip_rounded,
                "Zero Ad/Trackers Policy",
                "WeSafe does not run advertising scripts or sell telemetry packages to marketing agencies.",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrustBullet(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.poppins(
                  color: AppColors.mutedText,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 9. CALL TO ACTION SECTION
  Widget _buildCTASection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primaryPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.offline_bolt_rounded, color: Colors.white, size: 44),
          const SizedBox(height: 14),
          Text(
            "Be protected even when you cannot ask for help.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Ensure voice detection and SOS alerts are configured on your dashboard for maximum stealth safety.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            onPressed: () {
              Navigator.pop(context);
              Fluttertoast.showToast(
                msg: "Active Safety Shield check active. Double check your settings on home.",
                toastLength: Toast.LENGTH_LONG,
                backgroundColor: AppColors.successGreen,
                textColor: Colors.white,
              );
            },
            child: Text(
              "ENABLE ACTIVE SHIELD",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                icon: const Icon(Icons.people_alt_rounded, size: 14),
                label: Text(
                  "SOS Contacts",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MyContactsScreen()),
                  );
                },
              ),
              const SizedBox(width: 14),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                icon: const Icon(Icons.keyboard_voice_rounded, size: 14),
                label: Text(
                  "Set Safe Words",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Fluttertoast.showToast(
                    msg: "Change safe words trigger index on home settings panel.",
                    backgroundColor: AppColors.primaryPurple,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLicenceTile(BuildContext context) {
    return Container(
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        onTap: () => _showLicences(context),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.assignment_rounded, color: AppColors.primaryPurple, size: 18),
          ),
        ),
        title: Text(
          "Open Source Licences",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.textDark,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.mutedText),
      ),
    );
  }

  void _showLicences(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationVersion: "1.0.0",
      applicationIcon: Image.asset(
        "assets/wesafelogo.png",
        height: 48,
        errorBuilder: (_, __, ___) => const Icon(Icons.shield_outlined, color: AppColors.primaryDark, size: 48),
      ),
      applicationName: "WeSafe - Women Safety",
      applicationLegalese:
          "WeSafe is providing a premium safety-tech solution to protect individuals in danger, featuring a user-friendly application aiming to connect you with the ones who care for you!",
    );
  }
}

// ==========================================
// ANIMATED HERO SECTION WIDGET
// ==========================================
class HeroSection extends StatefulWidget {
  const HeroSection({Key? key}) : super(key: key);

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final double glowValue = _pulseController.value;
            final double scale = 1.0 + (glowValue * 0.08);
            final double blur = 24.0 + (glowValue * 20.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withOpacity(0.24),
                        blurRadius: blur,
                        spreadRadius: glowValue * 12.0,
                      ),
                      BoxShadow(
                        color: AppColors.softLavender.withOpacity(0.12),
                        blurRadius: blur * 1.5,
                        spreadRadius: glowValue * 6.0,
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.24),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.55),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Image.asset(
                        "assets/wesafelogo.png",
                        height: 52,
                        width: 52,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield_rounded,
                          color: AppColors.primaryDark,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          "WeSafe",
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          "Your Safety Guardian",
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryPurple,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Safety that listens, reacts, and protects — even when you can't speak.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textDark,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// SEQUENTIAL ENTRANCE TRANSITION WIDGET
// ==========================================
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;

  const FadeInSlide({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 650),
    this.delay = Duration.zero,
    this.offset = const Offset(0.0, 24.0),
  }) : super(key: key);

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

// ==========================================
// ANIMATED COUNT-UP NUMBER WIDGET
// ==========================================
class AnimatedCounter extends StatelessWidget {
  final double endValue;
  final String prefix;
  final String suffix;
  final int decimals;

  const AnimatedCounter({
    Key? key,
    required this.endValue,
    this.prefix = "",
    this.suffix = "",
    this.decimals = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: endValue),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          "$prefix${value.toStringAsFixed(decimals)}$suffix",
          style: GoogleFonts.shareTechMono(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        );
      },
    );
  }
}

// ==========================================
// PREMIUM PROFILE CARD WIDGET
// ==========================================
class MemberProfileCard extends StatefulWidget {
  final String name;
  final String role;
  final int index;

  const MemberProfileCard({
    Key? key,
    required this.name,
    required this.role,
    required this.index,
  }) : super(key: key);

  @override
  State<MemberProfileCard> createState() => _MemberProfileCardState();
}

class _MemberProfileCardState extends State<MemberProfileCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double scale = _isPressed ? 0.98 : (_isHovered ? 1.03 : 1.0);
    final double offset = _isHovered ? -5.0 : 0.0;
    final double shadowBlur = _isHovered ? 20.0 : 10.0;
    final double shadowOpacity = _isHovered ? 0.18 : 0.05;

    final String initial = widget.name.isNotEmpty ? widget.name[0] : "";

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0.0, offset, 0.0) *
              Matrix4.diagonal3Values(scale, scale, 1.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.24),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _isHovered ? AppColors.softLavender.withOpacity(0.6) : Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(shadowOpacity),
                blurRadius: shadowBlur,
                spreadRadius: _isHovered ? 3 : 1,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar with soft glow ring
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(3.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isHovered ? AppColors.softLavender : AppColors.primaryPurple.withOpacity(0.2),
                    width: 2.0,
                  ),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: AppColors.softLavender.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryPurple.withOpacity(0.12),
                  child: Text(
                    initial,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Full Name
              Text(
                widget.name,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Role Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryPurple.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.role,
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryPurple,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
