import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const FlutterSecureStorage storage = FlutterSecureStorage();

  static const String accessTokenKey  = "access_token";
  static const String refreshTokenKey = "refresh_token";

  // "Remember Me" persistent device token.
  // Survives app uninstall on Android (stored in AccountManager) and iOS (Keychain).
  static const String deviceTokenKey  = "device_token";

  // ── Access / Refresh tokens ──────────────────────────────────────────────

  static Future<void> saveAccessToken(String token) async {
    await storage.write(key: accessTokenKey, value: token);
  }

  static Future<void> saveRefreshToken(String token) async {
    await storage.write(key: refreshTokenKey, value: token);
  }

  static Future<void> saveTokens(String access, String refresh) async {
    await storage.write(key: accessTokenKey,  value: access);
    await storage.write(key: refreshTokenKey, value: refresh);
  }

  static Future<String?> getAccessToken() async {
    return await storage.read(key: accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return await storage.read(key: refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    await storage.delete(key: accessTokenKey);
    await storage.delete(key: refreshTokenKey);
    // Note: deviceToken is intentionally NOT cleared here.
    // It is only cleared on explicit logout (clearAll).
  }

  // ── Device token ("Remember Me") ────────────────────────────────────────

  static Future<void> saveDeviceToken(String token) async {
    await storage.write(key: deviceTokenKey, value: token);
  }

  static Future<String?> getDeviceToken() async {
    return await storage.read(key: deviceTokenKey);
  }

  static Future<void> clearDeviceToken() async {
    await storage.delete(key: deviceTokenKey);
  }

  // ── Full clear (used on explicit logout) ────────────────────────────────

  static Future<void> clearAll() async {
    await storage.delete(key: accessTokenKey);
    await storage.delete(key: refreshTokenKey);
    await storage.delete(key: deviceTokenKey);
  }
}
