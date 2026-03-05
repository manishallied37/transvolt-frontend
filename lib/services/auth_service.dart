import 'dart:convert';
import 'package:http/http.dart' as http;

import 'token_storage.dart';

class AuthService {
  static const String baseUrl = "http://192.168.0.66:5000";

  static Future<bool> login(
    String username,
    String password,
    String deviceId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/login"),

        headers: {"Content-Type": "application/json"},

        body: jsonEncode({
          "username": username,
          "password": password,
          "deviceId": deviceId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String accessToken = data["accessToken"];
        String refreshToken = data["refreshToken"];

        await TokenStorage.saveAccessToken(accessToken);
        await TokenStorage.saveRefreshToken(refreshToken);

        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Login Error: $e");

      return false;
    }
  }

  static Future<void> logout() async {
    await TokenStorage.clearTokens();
  }
}
