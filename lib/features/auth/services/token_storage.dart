import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const FlutterSecureStorage storage = FlutterSecureStorage();

  static const String accessTokenKey = "access_token";
  static const String refreshTokenKey = "refresh_token";

  static Future<void> saveAccessToken(String token) async {
    await storage.write(key: accessTokenKey, value: token);
  }

  static Future<void> saveRefreshToken(String token) async {
    await storage.write(key: refreshTokenKey, value: token);
  }

  static Future<void> saveTokens(String access, String refresh) async {
    await storage.write(key: accessTokenKey, value: access);
    await storage.write(key: refreshTokenKey, value: refresh);
  }

  static Future<String?> getAccessToken() async {
    return await storage.read(key: accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return await storage.read(key: refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    await storage.deleteAll();
  }
}
