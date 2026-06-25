import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:womensafteyhackfair/cloud_service.dart';

enum DeviceType { watch, pendant }

class BluetoothWearable {
  final String id;
  final String name;
  final DeviceType type;
  bool isConnected;
  int batteryPercentage;
  DateTime lastSync;

  BluetoothWearable({
    required this.id,
    required this.name,
    required this.type,
    this.isConnected = false,
    this.batteryPercentage = 100,
    required this.lastSync,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'isConnected': isConnected,
        'batteryPercentage': batteryPercentage,
        'lastSync': lastSync.toIso8601String(),
      };

  factory BluetoothWearable.fromJson(Map<String, dynamic> json) => BluetoothWearable(
        id: json['id'],
        name: json['name'],
        type: DeviceType.values[json['type']],
        isConnected: json['isConnected'] ?? false,
        batteryPercentage: json['batteryPercentage'] ?? 100,
        lastSync: DateTime.parse(json['lastSync']),
      );
}

class BluetoothService extends ChangeNotifier {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final List<BluetoothWearable> _pairedDevices = [];
  bool _isPhoneAppActive = true;

  bool _isWatchConnecting = false;
  bool _isPendantConnecting = false;

  // Callback for SOS triggers from wearables
  // Passes the trigger type ('watch_sos' | 'pendant_sos' | 'pendant_silent_sos') and forceSilent flag
  Function(String triggerType, {bool forceSilent})? _onSOSTrigger;

  // ─── Getters ─────────────────────────────────────────────────────────────
  List<BluetoothWearable> get pairedDevices => List.unmodifiable(_pairedDevices);
  
  bool get isWatchConnected =>
      _pairedDevices.any((d) => d.type == DeviceType.watch && d.isConnected);
      
  bool get isPendantConnected =>
      _pairedDevices.any((d) => d.type == DeviceType.pendant && d.isConnected);

  bool get isPhoneAppActive => _isPhoneAppActive;
  bool get isWatchConnecting => _isWatchConnecting;
  bool get isPendantConnecting => _isPendantConnecting;

  int get watchBattery => isWatchConnected ? 88 : 0;
  int get pendantBattery => isPendantConnected ? 74 : 0;

  DateTime? get watchLastSync {
    try {
      final dev = _pairedDevices.firstWhere((d) => d.type == DeviceType.watch && d.isConnected);
      return dev.lastSync;
    } catch (_) {
      return null;
    }
  }

  DateTime? get pendantLastSync {
    try {
      final dev = _pairedDevices.firstWhere((d) => d.type == DeviceType.pendant && d.isConnected);
      return dev.lastSync;
    } catch (_) {
      return null;
    }
  }

  int get signalStrength {
    if (isWatchConnected && isPendantConnected) {
      return -52; // Excellent signal when both are connected
    } else if (isWatchConnected || isPendantConnected) {
      return -65; // Good signal
    }
    return 0; // No signal
  }

  String get activeDevice {
    if (_isPhoneAppActive) {
      return "Phone App";
    } else if (isWatchConnected) {
      return "Smart Watch";
    } else if (isPendantConnected) {
      return "Safety Pendant";
    } else {
      return "None";
    }
  }

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> init({Function(String triggerType, {bool forceSilent})? onSOSTrigger}) async {
    _onSOSTrigger = onSOSTrigger;
    await loadPairedDevices();
  }

  // ─── Connect / Disconnect Smart Watch ─────────────────────────────────────
  Future<void> connectWatch() async {
    if (_isWatchConnecting || isWatchConnected) return;
    _isWatchConnecting = true;
    notifyListeners();

    // Simulate Bluetooth discovery and connection handshake delay
    await Future.delayed(const Duration(milliseconds: 1500));

    final wearable = BluetoothWearable(
      id: 'sim_watch_id',
      name: 'WeSafe Watch (Simulated)',
      type: DeviceType.watch,
      isConnected: true,
      batteryPercentage: 88,
      lastSync: DateTime.now(),
    );

    final existingIdx = _pairedDevices.indexWhere((d) => d.id == wearable.id);
    if (existingIdx >= 0) {
      _pairedDevices[existingIdx] = wearable;
    } else {
      _pairedDevices.add(wearable);
    }

    _isWatchConnecting = false;
    await savePairedDevices();
    await _syncDeviceStatusToFirebase();
    notifyListeners();
    debugPrint('✅ Simulated Smart Watch connected successfully.');
  }

  Future<void> disconnectWatch() async {
    final idx = _pairedDevices.indexWhere((d) => d.type == DeviceType.watch);
    if (idx >= 0) {
      _pairedDevices[idx].isConnected = false;
      await savePairedDevices();
      await _syncDeviceStatusToFirebase();
      notifyListeners();
      debugPrint('📡 Smart Watch disconnected.');
    }
  }

  // ─── Connect / Disconnect Safety Pendant ─────────────────────────────────
  Future<void> connectPendant() async {
    if (_isPendantConnecting || isPendantConnected) return;
    _isPendantConnecting = true;
    notifyListeners();

    // Simulate Bluetooth discovery and connection handshake delay
    await Future.delayed(const Duration(milliseconds: 1500));

    final wearable = BluetoothWearable(
      id: 'sim_pendant_id',
      name: 'WeSafe Pendant (Simulated)',
      type: DeviceType.pendant,
      isConnected: true,
      batteryPercentage: 74,
      lastSync: DateTime.now(),
    );

    final existingIdx = _pairedDevices.indexWhere((d) => d.id == wearable.id);
    if (existingIdx >= 0) {
      _pairedDevices[existingIdx] = wearable;
    } else {
      _pairedDevices.add(wearable);
    }

    _isPendantConnecting = false;
    await savePairedDevices();
    await _syncDeviceStatusToFirebase();
    notifyListeners();
    debugPrint('✅ Simulated Safety Pendant connected successfully.');
  }

  Future<void> disconnectPendant() async {
    final idx = _pairedDevices.indexWhere((d) => d.type == DeviceType.pendant);
    if (idx >= 0) {
      _pairedDevices[idx].isConnected = false;
      await savePairedDevices();
      await _syncDeviceStatusToFirebase();
      notifyListeners();
      debugPrint('📡 Safety Pendant disconnected.');
    }
  }

  // ─── Phone App State Control (Failover Simulator) ─────────────────────────
  void setPhoneAppActive(bool active) {
    _isPhoneAppActive = active;
    _syncDeviceStatusToFirebase();
    notifyListeners();
    debugPrint('📱 Phone App Active set to: $active. Active safety device recalculation: $activeDevice');
  }

  // ─── Simulated SOS Triggers ──────────────────────────────────────────────
  void simulateWatchSOS() {
    if (!isWatchConnected) {
      debugPrint('⚠️ Cannot trigger Watch SOS: Smart Watch is not connected.');
      return;
    }
    // Watch trigger works even if phone screen is locked, is active safety device
    debugPrint('🚨 Watch SOS trigger received.');
    _onSOSTrigger?.call('watch_sos', forceSilent: false);
  }

  void simulatePendantPress(bool isLongPress) {
    if (!isPendantConnected) {
      debugPrint('⚠️ Cannot trigger Pendant SOS: Safety Pendant is not connected.');
      return;
    }
    if (isLongPress) {
      debugPrint('🚨 Pendant Long Press received (Silent SOS).');
      _onSOSTrigger?.call('pendant_silent_sos', forceSilent: true);
    } else {
      debugPrint('🚨 Pendant Single Press received (Normal SOS).');
      _onSOSTrigger?.call('pendant_sos', forceSilent: false);
    }
  }

  // ─── Persistence ─────────────────────────────────────────────────────────
  Future<void> savePairedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _pairedDevices.map((d) => jsonEncode(d.toJson())).toList();
      await prefs.setStringList('paired_devices', list);
    } catch (e) {
      debugPrint('❌ Error saving paired devices: $e');
    }
  }

  Future<void> loadPairedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('paired_devices') ?? [];
      _pairedDevices.clear();
      for (final item in list) {
        try {
          _pairedDevices.add(BluetoothWearable.fromJson(
              jsonDecode(item) as Map<String, dynamic>));
        } catch (_) {}
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading paired devices: $e');
    }
  }

  // ─── Firebase Syncing ─────────────────────────────────────────────────────
  Future<void> _syncDeviceStatusToFirebase() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null && userId.isNotEmpty) {
      await CloudService().updateDeviceStatus(
        userId,
        watchConnected: isWatchConnected,
        pendantConnected: isPendantConnected,
        activeDevice: activeDevice,
      );
    }
  }

  // ─── Sync Device Hub Data ──────────────────────────────────────────────────
  Future<void> syncDeviceHub() async {
    for (var d in _pairedDevices) {
      if (d.isConnected) {
        d.lastSync = DateTime.now();
      }
    }
    await savePairedDevices();
    await _syncDeviceStatusToFirebase();
    notifyListeners();
    debugPrint("Synced wearable device configuration states to cloud database.");
  }
}
