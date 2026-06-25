// Web Bluetooth stub helper for compile-time safety on mobile platforms.

bool get isWebBluetoothSupported => false;

void registerWebCallbacks({
  required Function(String deviceId) onSOSTriggered,
  required Function(String deviceId) onDeviceDisconnected,
}) {}

Future<Map<String, dynamic>?> connectWebDevice() async {
  return null;
}

Future<void> disconnectWebDevice(String id) async {}
