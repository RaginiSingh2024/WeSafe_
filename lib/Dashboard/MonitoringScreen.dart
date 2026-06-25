import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:womensafteyhackfair/Dashboard/DashWidgets/WeSafeToast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:womensafteyhackfair/constants.dart';
import 'package:womensafteyhackfair/voice_detection_service.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({Key? key}) : super(key: key);

  @override
  _MonitoringScreenState createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> with SingleTickerProviderStateMixin {
  final VoiceDetectionService _voiceService = VoiceDetectionService();
  late AnimationController _waveController;
  final TextEditingController _addController = TextEditingController();
  final TextEditingController _scoreController = TextEditingController();
  
  int _selectedTab = 0; // 0 for Custom Keywords, 1 for Default Keywords, 2 for Voice Engine Settings

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (_voiceService.isListening) {
      _waveController.repeat();
    }
    _voiceService.addListener(_onVoiceServiceStateChanged);
  }

  @override
  void dispose() {
    _voiceService.removeListener(_onVoiceServiceStateChanged);
    _waveController.dispose();
    _addController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  void _onVoiceServiceStateChanged() {
    if (mounted) {
      setState(() {});
      if (_voiceService.isListening) {
        if (!_waveController.isAnimating) {
          _waveController.repeat();
        }
      } else {
        if (_waveController.isAnimating) {
          _waveController.stop();
        }
      }
    }
  }

  void _showAddDialog() {
    _addController.clear();
    _scoreController.text = "50";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Add Panic Keyword",
          style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _addController,
              style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Enter phrase...",
                hintStyle: const TextStyle(color: AppColors.mutedText),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.mutedBlushLavender.withOpacity(0.6)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.softLavender, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _scoreController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Enter panic score (e.g. 50)...",
                hintStyle: const TextStyle(color: AppColors.mutedText),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.mutedBlushLavender.withOpacity(0.6)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.softLavender, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: AppColors.mutedText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              int score = int.tryParse(_scoreController.text) ?? 50;
              _voiceService.addCustomKeyword(_addController.text, score);
              Navigator.pop(context);
            },
            child: const Text("Add", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(int index, PanicKeyword keyword) {
    _addController.text = keyword.phrase;
    _scoreController.text = keyword.scoreValue.toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Edit Panic Keyword",
          style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _addController,
              style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Enter phrase...",
                hintStyle: const TextStyle(color: AppColors.mutedText),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.mutedBlushLavender.withOpacity(0.6)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.softLavender, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _scoreController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Enter panic score...",
                hintStyle: const TextStyle(color: AppColors.mutedText),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.mutedBlushLavender.withOpacity(0.6)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.softLavender, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: AppColors.mutedText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              int score = int.tryParse(_scoreController.text) ?? 50;
              _voiceService.editCustomKeyword(index, _addController.text, score);
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Safety Intelligence",
                        style: GoogleFonts.poppins(
                          color: AppColors.mutedText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Voice Monitoring",
                        style: GoogleFonts.poppins(
                          color: AppColors.textDark,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryDark.withOpacity(0.2)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _voiceService.isListening ? AppColors.successGreen : AppColors.mutedText,
                            shape: BoxShape.circle,
                            boxShadow: _voiceService.isListening
                                ? [
                                    BoxShadow(
                                      color: AppColors.successGreen.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _voiceService.isListening ? "ACTIVE" : "PAUSED",
                          style: GoogleFonts.poppins(
                            color: _voiceService.isListening ? AppColors.successGreen : AppColors.mutedText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Layout splits for desktop and mobile
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildVisualizerCard()),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _buildKeywordsCard()),
                  ],
                )
              else
                Column(
                  children: [
                    _buildVisualizerCard(),
                    const SizedBox(height: 24),
                    _buildKeywordsCard(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualizerCard() {
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Live Voice Visualizer",
                    style: GoogleFonts.poppins(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  Switch(
                    value: _voiceService.isEnabled,
                    activeColor: AppColors.softLavender,
                    activeTrackColor: AppColors.primaryDark.withOpacity(0.25),
                    inactiveThumbColor: AppColors.mutedText,
                    inactiveTrackColor: AppColors.mutedBlushLavender.withOpacity(0.4),
                    onChanged: (value) {
                      _voiceService.setEnabled(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Waveform visualizer
              SizedBox(
                height: 120,
                child: _voiceService.isListening
                    ? AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(24, (index) {
                              // Create shifting sin wave style bars responding dynamically to voice levels
                              double angle = (_waveController.value * 2 * pi) + (index * 0.4);
                              // dynamic height modifier based on sound level
                              double soundModifier = (_voiceService.currentSoundLevel + 10.0).abs() * 3.5;
                              if (soundModifier > 70.0) soundModifier = 70.0;
                              double heightFactor = (sin(angle).abs() * 0.3) + 0.1 + (soundModifier / 100);
                              
                              return Container(
                                width: 6,
                                height: 100 * heightFactor,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primaryDark, AppColors.softLavender],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.softLavender.withOpacity(0.25),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                              );
                            }),
                          );
                        },
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(24, (index) {
                          return Container(
                            width: 6,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.mutedBlushLavender.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
              ),
              const SizedBox(height: 32),
              Text(
                _voiceService.isListening ? "WeSafe is Listening..." : "Monitoring Paused",
                style: GoogleFonts.poppins(
                  color: _voiceService.isListening ? AppColors.primaryDark : AppColors.mutedText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "AI speech guardian is active in the background.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppColors.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              
              // Live Panic Score progress card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Live Threat Score Level",
                          style: GoogleFonts.poppins(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "${_voiceService.currentScore} / 70",
                          style: GoogleFonts.shareTechMono(
                            color: _voiceService.currentScore >= 50
                                ? AppColors.emergencyRed
                                : (_voiceService.currentScore >= 30 ? AppColors.warningOrange : AppColors.successGreen),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _voiceService.currentScore / 100,
                        minHeight: 12,
                        backgroundColor: AppColors.primaryDark.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _voiceService.currentScore >= 70
                              ? AppColors.emergencyRed
                              : (_voiceService.currentScore >= 40 ? AppColors.warningOrange : AppColors.softLavender),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _voiceService.currentScore >= 50
                              ? "THREAT STATUS: CRITICAL"
                              : (_voiceService.currentScore >= 30 ? "THREAT STATUS: ELEVATED" : "THREAT STATUS: SAFE"),
                          style: GoogleFonts.poppins(
                            color: _voiceService.currentScore >= 50
                                ? AppColors.emergencyRed
                                : (_voiceService.currentScore >= 30 ? AppColors.warningOrange : AppColors.successGreen),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          "Trigger Level: 70",
                          style: GoogleFonts.poppins(
                            color: AppColors.mutedText,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Speech Output container
              if (_voiceService.lastRecognizedWords.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryDark.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Last Speech Input:",
                        style: GoogleFonts.poppins(
                          color: AppColors.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "\"${_voiceService.lastRecognizedWords}\"",
                        style: GoogleFonts.poppins(
                          color: AppColors.textDark,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (_voiceService.lastDetectedKeyword.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.emergencyRed, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "Detected: ${_voiceService.lastDetectedKeyword}",
                              style: GoogleFonts.poppins(
                                color: AppColors.emergencyRed,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Metrics
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCol("Confidence", "${(_voiceService.lastConfidence * 100).toInt()}%", AppColors.primaryDark),
                    Container(width: 1, height: 40, color: AppColors.mutedBlushLavender.withOpacity(0.5)),
                    _buildMetricCol("Audio Level", "${_voiceService.currentSoundLevel.toStringAsFixed(1)} dB", AppColors.successGreen),
                    Container(width: 1, height: 40, color: AppColors.mutedBlushLavender.withOpacity(0.5)),
                    _buildMetricCol("Lang Code", _voiceService.selectedLanguage.toUpperCase(), AppColors.warningOrange),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color accentColor) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: accentColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildKeywordsCard() {
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTabButton(0, "Custom"),
                  _buildTabButton(1, "Built-in"),
                  _buildTabButton(2, "Settings"),
                ],
              ),
              const SizedBox(height: 24),
              if (_selectedTab == 0) _buildCustomKeywordsTab(),
              if (_selectedTab == 1) _buildBuiltinKeywordsTab(),
              if (_selectedTab == 2) _buildVoiceSettingsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    bool isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark.withOpacity(0.2) : Colors.transparent,
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            color: isSelected ? AppColors.primaryDark : AppColors.mutedText,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomKeywordsTab() {
    final customKeywords = _voiceService.customKeywords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Panic Phrases",
              style: GoogleFonts.poppins(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            InkWell(
              onTap: _showAddDialog,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryDark.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add, color: AppColors.primaryDark, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "ADD NEW",
                      style: GoogleFonts.poppins(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Register custom spoken triggers to initiate rescue dispatch.",
          style: GoogleFonts.poppins(
            color: AppColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        if (customKeywords.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warningOrange.withOpacity(0.5), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    "No custom words registered",
                    style: GoogleFonts.poppins(color: AppColors.mutedText, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: customKeywords.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final kw = customKeywords[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kw.phrase,
                            style: GoogleFonts.poppins(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Score Impact: +${kw.scoreValue}",
                            style: GoogleFonts.poppins(
                              color: AppColors.primaryPurple,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _voiceService.simulateVoiceTrigger(kw.phrase, kw.scoreValue);
                            WeSafeToast.showSuccess(
                              title: 'Keyword Simulated',
                              message: 'Testing: Detected keyword "${kw.phrase}"',
                              status: 'TEST',
                            );
                          },
                          child: Text(
                            "TEST",
                            style: GoogleFonts.poppins(
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.edit_rounded, color: AppColors.mutedText, size: 18),
                          onPressed: () => _showEditDialog(index, kw),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.delete_rounded, color: AppColors.emergency, size: 18),
                          onPressed: () => _voiceService.deleteCustomKeyword(index),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBuiltinKeywordsTab() {
    final builtinKeywords = _voiceService.builtinKeywords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Built-in Trigger Phrases",
          style: GoogleFonts.poppins(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Pre-configured multilingual panic trigger words recognized natively.",
          style: GoogleFonts.poppins(
            color: AppColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: builtinKeywords.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final kw = builtinKeywords[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      kw.phrase,
                      style: GoogleFonts.poppins(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "+${kw.scoreValue}",
                          style: GoogleFonts.shareTechMono(
                            color: AppColors.softLavender,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.hearing_rounded, color: AppColors.successGreen, size: 16),
                          onPressed: () {
                            _voiceService.simulateVoiceTrigger(kw.phrase, kw.scoreValue);
                            WeSafeToast.showSuccess(
                              title: 'Keyword Simulated',
                              message: 'Simulating: "${kw.phrase}"',
                              status: 'TEST',
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Voice Guardian Settings",
          style: GoogleFonts.poppins(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Listening Language",
              style: GoogleFonts.poppins(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.mutedBlushLavender.withOpacity(0.5)),
              ),
              child: DropdownButton<String>(
                value: _voiceService.selectedLanguage,
                underline: const SizedBox(),
                style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 13),
                dropdownColor: Colors.white.withOpacity(0.95),
                items: const [
                  DropdownMenuItem(value: "en-US", child: Text("English (US)")),
                  DropdownMenuItem(value: "hi-IN", child: Text("Hindi (भारत)")),
                  DropdownMenuItem(value: "mr-IN", child: Text("Marathi (भारत)")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    _voiceService.setSelectedLanguage(val);
                    WeSafeToast.showSuccess(
                      title: 'Language Selected',
                      message: 'Locale updated to $val successfully.',
                      status: 'OK',
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Voice Sensitivity",
                  style: GoogleFonts.poppins(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "${(_voiceService.sensitivity * 100).toInt()}%",
                  style: GoogleFonts.shareTechMono(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Slider(
              value: _voiceService.sensitivity,
              activeColor: AppColors.softLavender,
              inactiveColor: AppColors.mutedBlushLavender.withOpacity(0.4),
              onChanged: (val) {
                _voiceService.setSensitivity(val);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Stealth Protection Mode",
            style: GoogleFonts.poppins(
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            "Silent alert dispatch (no sirens, vibrations, or flashes on screen).",
            style: GoogleFonts.poppins(color: AppColors.mutedText, fontSize: 11),
          ),
          value: _voiceService.isSilentMode,
          activeColor: AppColors.softLavender,
          activeTrackColor: AppColors.primaryDark.withOpacity(0.25),
          onChanged: (val) {
            _voiceService.setSilentMode(val);
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Trigger Motion Anomaly",
                style: GoogleFonts.poppins(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple.withOpacity(0.12),
                foregroundColor: AppColors.primaryPurple,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _voiceService.simulateMotionAnomaly();
                WeSafeToast.showWarning(
                  title: 'Anomaly Triggered',
                  message: 'Motion Anomaly simulation triggered (+40 score)',
                  status: 'TEST',
                );
              },
              child: Text(
                "SIMULATE",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
