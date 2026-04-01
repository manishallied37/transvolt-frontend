import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const _secureStorage = FlutterSecureStorage();

  static const String _deviceIdKey = "secure_device_id";
  static const String _deviceRegisteredKey = "device_registered";

  /// 🔐 Get or create secure device ID
  static Future<String> getDeviceId() async {
    String? stored = await _secureStorage.read(key: _deviceIdKey);

    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final deviceId = await _resolveHardwareId();

    await _secureStorage.write(key: _deviceIdKey, value: deviceId);

    return deviceId;
  }

  /// 🔍 Hardware-based fallback (only used once)
  static Future<String> _resolveHardwareId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      return webInfo.userAgent ?? "web-device";
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = await deviceInfo.androidInfo;
      return android.id; // ANDROID_ID
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = await deviceInfo.iosInfo;
      return ios.identifierForVendor ?? "ios-device";
    }

    return "unknown-device";
  }

  /// ✅ Device registration flag (non-sensitive)
  static Future<bool> isDeviceRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_deviceRegisteredKey) ?? false;
  }

  static Future<void> registerDevice() async {
    final prefs = await SharedPreferences.getInstance();

    // Ensure deviceId exists securely
    await getDeviceId();

    await prefs.setBool(_deviceRegisteredKey, true);
  }

  /// 🔐 Always read from secure storage
  static Future<String?> getStoredDeviceId() async {
    return await _secureStorage.read(key: _deviceIdKey);
  }

  /// 🧹 Clear both secure + prefs
  static Future<void> clearDevice() async {
    final prefs = await SharedPreferences.getInstance();

    await _secureStorage.delete(key: _deviceIdKey);
    await prefs.remove(_deviceRegisteredKey);
  }

  static Future<void> migrateDeviceIdIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // Check secure storage first
    String? secureId = await _secureStorage.read(key: _deviceIdKey);

    if (secureId != null && secureId.isNotEmpty) {
      return; // Already migrated
    }

    // Check old SharedPreferences
    String? oldId = prefs.getString("device_id");

    if (oldId != null && oldId.isNotEmpty) {
      // Move to secure storage
      await _secureStorage.write(key: _deviceIdKey, value: oldId);

      // Clean up insecure storage
      await prefs.remove("device_id");
    }
  }
}
