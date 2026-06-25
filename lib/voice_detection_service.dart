import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vibration/vibration.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:womensafteyhackfair/constants.dart';


class PanicKeyword {
  final String phrase;
  final bool isEnabled;
  final int scoreValue;

  PanicKeyword({
    required this.phrase,
    this.isEnabled = true,
    this.scoreValue = 50,
  });

  Map<String, dynamic> toJson() => {
        'phrase': phrase,
        'isEnabled': isEnabled,
        'scoreValue': scoreValue,
      };

  factory PanicKeyword.fromJson(Map<String, dynamic> json) => PanicKeyword(
        phrase: json['phrase'] as String,
        isEnabled: json['isEnabled'] as bool? ?? true,
        scoreValue: json['scoreValue'] as int? ?? 50,
      );
}

class VoiceDetectionService extends ChangeNotifier {
  static final VoiceDetectionService _instance = VoiceDetectionService._internal();
  factory VoiceDetectionService() => _instance;
  VoiceDetectionService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  
  // Settings
  bool _isEnabled = true;
  double _sensitivity = 0.7; // mapped to confidence threshold or sound floor
  String _selectedLanguage = "en-US"; // "en-US", "hi-IN", "mr-IN"
  bool _isSilentMode = true; // Mode 1: Silent, Mode 2: Active (Alarm & Flash)
  
  // Real-time State
  int _currentScore = 0;
  String _lastRecognizedWords = "";
  String _lastDetectedKeyword = "";
  double _lastConfidence = 0.0;
  double _currentSoundLevel = 0.0;
  
  // Custom Keywords list
  List<PanicKeyword> _customKeywords = [];
  
  // Built-in Keywords
  final List<PanicKeyword> _builtinKeywords = [
    PanicKeyword(phrase: "HELP", scoreValue: 50),
    PanicKeyword(phrase: "STOP", scoreValue: 40),
    PanicKeyword(phrase: "SAVE ME", scoreValue: 70),
    PanicKeyword(phrase: "LEAVE ME", scoreValue: 50),
    PanicKeyword(phrase: "NO", scoreValue: 50),
    PanicKeyword(phrase: "CALL POLICE", scoreValue: 80),
    PanicKeyword(phrase: "DON'T TOUCH ME", scoreValue: 50),
    PanicKeyword(phrase: "SOMEONE HELP", scoreValue: 50),
    PanicKeyword(phrase: "I'M IN DANGER", scoreValue: 80),
    PanicKeyword(phrase: "EMERGENCY", scoreValue: 80),
    PanicKeyword(phrase: "HELP ME", scoreValue: 50),
    PanicKeyword(phrase: "LET ME GO", scoreValue: 50),
    PanicKeyword(phrase: "GET AWAY", scoreValue: 50),
    PanicKeyword(phrase: "PLEASE STOP", scoreValue: 40),
    // Hindi
    PanicKeyword(phrase: "बचाओ", scoreValue: 50),
    PanicKeyword(phrase: "मदद", scoreValue: 70),
    PanicKeyword(phrase: "रुको", scoreValue: 40),
    PanicKeyword(phrase: "छोड़ दो", scoreValue: 50),
    // Marathi
    PanicKeyword(phrase: "वाचवा", scoreValue: 50),
    PanicKeyword(phrase: "मदत करा", scoreValue: 70),
  ];

  // Callback to trigger emergency alerts inside Dashboard
  Function(String keyword, int score)? onEmergencyTriggered;

  // Getters
  bool get isListening => _isListening;
  bool get isEnabled => _isEnabled;
  double get sensitivity => _sensitivity;
  String get selectedLanguage => _selectedLanguage;
  bool get isSilentMode => _isSilentMode;
  int get currentScore => _currentScore;
  String get lastRecognizedWords => _lastRecognizedWords;
  String get lastDetectedKeyword => _lastDetectedKeyword;
  double get lastConfidence => _lastConfidence;
  double get currentSoundLevel => _currentSoundLevel;
  List<PanicKeyword> get customKeywords => _customKeywords;
  List<PanicKeyword> get builtinKeywords => _builtinKeywords;

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadSettings();
    _isInitialized = true;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool("voice_detection_enabled") ?? true;
    _sensitivity = prefs.getDouble("voice_sensitivity") ?? 0.7;
    _selectedLanguage = prefs.getString("voice_selected_language") ?? "en-US";
    _isSilentMode = prefs.getBool("voice_silent_mode") ?? true;

    // Load custom keywords
    final customList = prefs.getStringList("custom_panic_keywords") ?? [];
    _customKeywords = customList
        .map((item) => PanicKeyword.fromJson(jsonDecode(item)))
        .toList();

    // Default custom keywords if empty
    if (_customKeywords.isEmpty) {
      _customKeywords = [
        PanicKeyword(phrase: "My emergency", scoreValue: 60),
        PanicKeyword(phrase: "Unsafe", scoreValue: 60),
        PanicKeyword(phrase: "Need help now", scoreValue: 80),
      ];
      await _saveCustomKeywords();
    }
  }

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("voice_detection_enabled", value);
    if (!value) {
      await stopListening();
    } else {
      await startListening();
    }
    notifyListeners();
  }

  Future<void> setSensitivity(double value) async {
    _sensitivity = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble("voice_sensitivity", value);
    notifyListeners();
  }

  Future<void> setSelectedLanguage(String value) async {
    _selectedLanguage = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("voice_selected_language", value);
    if (_isListening) {
      // restart listening to apply new locale
      await stopListening();
      await startListening();
    }
    notifyListeners();
  }

  Future<void> setSilentMode(bool value) async {
    _isSilentMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("voice_silent_mode", value);
    notifyListeners();
  }

  Future<void> _saveCustomKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    final customList = _customKeywords.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList("custom_panic_keywords", customList);
  }

  void addCustomKeyword(String phrase, int score) {
    if (phrase.trim().isEmpty) return;
    _customKeywords.add(PanicKeyword(phrase: phrase.trim(), scoreValue: score));
    _saveCustomKeywords();
    notifyListeners();
  }

  void deleteCustomKeyword(int index) {
    if (index >= 0 && index < _customKeywords.length) {
      _customKeywords.removeAt(index);
      _saveCustomKeywords();
      notifyListeners();
    }
  }

  void editCustomKeyword(int index, String phrase, int score) {
    if (index >= 0 && index < _customKeywords.length && phrase.trim().isNotEmpty) {
      _customKeywords[index] = PanicKeyword(phrase: phrase.trim(), scoreValue: score);
      _saveCustomKeywords();
      notifyListeners();
    }
  }

  Future<void> startListening() async {
    if (!_isEnabled) return;
    
    // Check permission
    if (!kIsWeb) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          Fluttertoast.showToast(msg: "Microphone permission is required for Voice Detection.");
          return;
        }
      }
    }

    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint("Speech STT Status: $status");
          if (status == "done" || status == "notListening") {
            // Restart listening if we want continuous monitoring
            if (_isEnabled && _isListening) {
              _restartListeningDelayed();
            }
          }
        },
        onError: (error) {
          debugPrint("Speech STT Error: $error");
          if (_isEnabled && _isListening) {
            _restartListeningDelayed();
          }
        },
      );

      if (available) {
        _isListening = true;
        _speech.listen(
          onResult: (result) {
            _processSpeechResult(result.recognizedWords, result.confidence);
          },
          onSoundLevelChange: (level) {
            // Sound level changes
            _currentSoundLevel = level;
            // Scream Detection logic: high sound levels add to panic score
            if (level > 45.0) { // arbitrary loudness threshold
              _increasePanicScore(35, "Scream/Loud Sound");
            }
            notifyListeners();
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          localeId: _selectedLanguage,
          cancelOnError: false,
          listenMode: stt.ListenMode.confirmation,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error starting voice detection: $e");
    }
  }

  void _restartListeningDelayed() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_isEnabled && _isListening) {
        startListening();
      }
    });
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
    _currentScore = 0;
    _currentSoundLevel = 0.0;
    notifyListeners();
  }

  void _processSpeechResult(String words, double confidence) {
    _lastRecognizedWords = words;
    _lastConfidence = confidence;
    notifyListeners();

    String lowerWords = words.toLowerCase();
    
    // Check built-in and custom keywords
    List<PanicKeyword> allActiveKeywords = [..._builtinKeywords, ..._customKeywords];
    
    bool keywordDetected = false;
    int triggeredScore = 0;
    String detectedWord = "";

    for (var kw in allActiveKeywords) {
      if (!kw.isEnabled) continue;
      
      final keywordPhrase = kw.phrase.toLowerCase();
      if (lowerWords.contains(keywordPhrase)) {
        keywordDetected = true;
        detectedWord = kw.phrase;
        
        // Repetition detection: e.g. "HELP HELP" or "STOP STOP"
        int occurrences = keywordPhrase.allMatches(lowerWords).length;
        if (occurrences > 1) {
          triggeredScore += (kw.scoreValue * 1.5).toInt();
          _increasePanicScore(triggeredScore, "$detectedWord (Repeated)");
        } else {
          triggeredScore += kw.scoreValue;
          _increasePanicScore(triggeredScore, detectedWord);
        }
      }
    }

    // Confidence scoring bypass
    if (keywordDetected && confidence > 0.90) {
      _increasePanicScore(20, "High Confidence Signal");
    }
  }

  void _increasePanicScore(int scoreVal, String keyword) {
    // If in cooldown, ignore all score increases
    if (_isInCooldown) return;

    _currentScore += scoreVal;
    _lastDetectedKeyword = keyword;
    
    if (_currentScore > 100) _currentScore = 100;
    
    notifyListeners();

    // Check emergency threshold (70+)
    if (_currentScore >= 70) {
      _triggerEmergencyAlert(keyword);
    }
    
    // Decay the score slowly over time to avoid permanent high threat states
    _decayScoreAfterDelay();
  }

  Timer? _decayTimer;
  void _decayScoreAfterDelay() {
    _decayTimer?.cancel();
    _decayTimer = Timer(const Duration(seconds: 6), () {
      _decayTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
        if (_currentScore > 0) {
          _currentScore -= 5;
          if (_currentScore < 0) _currentScore = 0;
          notifyListeners();
        } else {
          timer.cancel();
        }
      });
    });
  }

  // Force trigger for manual/test simulation
  void simulateVoiceTrigger(String word, int score) {
    _increasePanicScore(score, word);
  }

  void simulateMotionAnomaly() {
    _increasePanicScore(40, "Motion Anomaly");
  }

  // ── Cooldown to prevent multiple triggers ──
  bool _isInCooldown = false;
  Timer? _cooldownTimer;
  static const int _cooldownSeconds = 60; // 60-second cooldown after each SOS

  void _triggerEmergencyAlert(String word) async {
    // Prevent multiple triggers
    if (_isInCooldown) return;

    _isInCooldown = true;
    int finalScore = _currentScore;
    _currentScore = 0; // reset score
    notifyListeners();

    if (onEmergencyTriggered != null) {
      onEmergencyTriggered!(word, finalScore);
    }

    // Start cooldown timer — no new SOS for 60 seconds
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(Duration(seconds: _cooldownSeconds), () {
      _isInCooldown = false;
      debugPrint('Voice SOS cooldown ended — ready for next detection.');
    });
  }

  /// Resets cooldown (e.g. when user disarms the alert manually)
  void resetCooldown() {
    _cooldownTimer?.cancel();
    _isInCooldown = false;
  }

  // Generate real logs
  Future<void> logAlert(String keyword, bool isSilent, String locationLink) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList("voice_alert_logs") ?? [];
    
    final newLog = {
      "timestamp": DateTime.now().toIso8601String(),
      "keyword": keyword,
      "mode": isSilent ? "Silent Protection" : "Active Emergency",
      "location": locationLink
    };

    logs.insert(0, jsonEncode(newLog));
    if (logs.length > 50) logs.removeLast(); // keep last 50 entries
    await prefs.setStringList("voice_alert_logs", logs);
  }
}
