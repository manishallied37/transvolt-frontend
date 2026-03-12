import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const String deviceRegisteredKey = "device_registered";
  static const String deviceIdKey = "device_id";

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    String? storedId = prefs.getString(deviceIdKey);

    if (storedId != null) {
      return storedId;
    }

    final deviceInfo = DeviceInfoPlugin();

    String deviceId = "unknown-device";

    if (kIsWeb) {
      WebBrowserInfo webInfo = await deviceInfo.webBrowserInfo;
      deviceId = webInfo.userAgent ?? "web-device";
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      AndroidDeviceInfo android = await deviceInfo.androidInfo;
      deviceId = android.id;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      IosDeviceInfo ios = await deviceInfo.iosInfo;
      deviceId = ios.identifierForVendor ?? "ios-device";
    }

    await prefs.setString(deviceIdKey, deviceId);

    return deviceId;
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
