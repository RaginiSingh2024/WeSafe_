// Web Bluetooth real helper using JS interop for web target.
// Fixed: safely checks for weSafeBluetooth JS object before calling isSupported.

import 'dart:js' as js;
import 'dart:js_util' as js_util;

/// Returns true only if the weSafeBluetooth JS bridge is present AND reports support.
bool get isWebBluetoothSupported {
  try {
    if (!js.context.hasProperty('weSafeBluetooth')) return false;
    final helper = js.context['weSafeBluetooth'];
    if (helper == null) return false;
    final result = js_util.callMethod(helper, 'isSupported', []);
    if (result == null) return false;
    return result == true;
  } catch (_) {
    return false;
  }
}

void registerWebCallbacks({
  required Function(String deviceId) onSOSTriggered,
  required Function(String deviceId) onDeviceDisconnected,
}) {
  if (!isWebBluetoothSupported) return;
  try {
    final helper = js.context['weSafeBluetooth'];
    js_util.callMethod(helper, 'registerCallbacks', [
      js.allowInterop((deviceId) => onSOSTriggered(deviceId as String)),
      js.allowInterop((deviceId) => onDeviceDisconnected(deviceId as String)),
    ]);
  } catch (_) {}
}

Future<Map<String, dynamic>?> connectWebDevice() async {
  if (!isWebBluetoothSupported) return null;
  try {
    final helper = js.context['weSafeBluetooth'];
    final promise = js_util.callMethod(helper, 'connect', []);
    final result = await js_util.promiseToFuture(promise);
    return {
      'id': js_util.getProperty(result, 'id'),
      'name': js_util.getProperty(result, 'name'),
      'type': js_util.getProperty(result, 'type'),
      'batteryPercentage': js_util.getProperty(result, 'batteryPercentage'),
    };
  } catch (_) {
    return null;
  }
}

Future<void> disconnectWebDevice(String id) async {
  if (!isWebBluetoothSupported) return;
  try {
    final helper = js.context['weSafeBluetooth'];
    js_util.callMethod(helper, 'disconnect', [id]);
  } catch (_) {}
}
