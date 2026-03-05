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
      }

      return false;
    } catch (e) {
      print("Login Error: $e");
      return false;
    }
  }

  static Future<bool> refreshAccessToken() async {
    try {
      String? refreshToken = await TokenStorage.getRefreshToken();

      if (refreshToken == null) {
        return false;
      }

      final response = await http.post(
        Uri.parse("$baseUrl/auth/refresh"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"refreshToken": refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String newAccessToken = data["accessToken"];
        String? newRefreshToken = data["refreshToken"];

        await TokenStorage.saveAccessToken(newAccessToken);

        if (newRefreshToken != null) {
          await TokenStorage.saveRefreshToken(newRefreshToken);
        }

        return true;
      }

      return false;
    } catch (e) {
      print("Refresh Token Error: $e");
      return false;
    }
  }

  static Future<bool> register(
    String username,
    String password,
    String role,
    String region,
    String depot,
    String deviceId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
          "role": role,
          "region": region,
          "depot": depot,
          "deviceId": deviceId,
          "deviceName": "Flutter Device",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await TokenStorage.saveAccessToken(data["accessToken"]);
        await TokenStorage.saveRefreshToken(data["refreshToken"]);

        return true;
      }

      return false;
    } catch (e) {
      print("Register error: $e");
      return false;
    }
  }
}
