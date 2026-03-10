import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const String deviceRegisteredKey = "device_registered";
  static const String deviceIdKey = "device_id";

  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (kIsWeb) {
      WebBrowserInfo webInfo = await deviceInfo.webBrowserInfo;
      return webInfo.userAgent ?? "web-device";
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      AndroidDeviceInfo android = await deviceInfo.androidInfo;
      return android.id;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      IosDeviceInfo ios = await deviceInfo.iosInfo;
      return ios.identifierForVendor ?? "unknown";
    }

    return "unknown-device";
  }

  static Future<bool> isDeviceRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(deviceRegisteredKey) ?? false;
  }

  static Future<void> registerDevice() async {
    final prefs = await SharedPreferences.getInstance();

    String deviceId = await getDeviceId();

    await prefs.setBool(deviceRegisteredKey, true);
    await prefs.setString(deviceIdKey, deviceId);
  }

  static Future<String?> getStoredDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(deviceIdKey);
  }

  static Future<void> clearDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(deviceRegisteredKey);
    await prefs.remove(deviceIdKey);
  }
}
