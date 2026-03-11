// TODO Implement this library.
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceService {
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
}
