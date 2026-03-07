import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'token_storage.dart';
import 'device_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static String baseUrl = dotenv.env['API_URL']!;
  static Dio dio = Dio(BaseOptions(baseUrl: baseUrl));

  static Future<bool> login(
    String login,
    String password,
    String deviceId,
  ) async {
    try {
      final response = await dio.post(
        "/auth/login",
        data: {"login": login, "password": password, "deviceId": deviceId},
      );

      if (response.statusCode == 200) {
        final data = response.data;

        String accessToken = data["accessToken"];
        String refreshToken = data["refreshToken"];

        await TokenStorage.saveAccessToken(accessToken);
        await TokenStorage.saveRefreshToken(refreshToken);

        return true;
      }

      return false;
    } catch (e) {
      debugPrint("Login Error: $e");
      return false;
    }
  }

  static Future<bool> refreshAccessToken() async {
    try {
      String? refreshToken = await TokenStorage.getRefreshToken();

      if (refreshToken == null) return false;

      final response = await dio.post(
        "/auth/refresh",
        data: {"refreshToken": refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;

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
      debugPrint("Refresh Token Error: $e");
      return false;
    }
  }

  static Future<bool> register(
    String username,
    String email,
    String password,
    String role,
    String region,
    String depot,
    String deviceId,
  ) async {
    try {
      final response = await dio.post(
        "/auth/register",
        data: {
          "username": username,
          "email": email,
          "password": password,
          "role": role,
          "region": region,
          "depot": depot,
          "deviceId": deviceId,
          "deviceName": "Flutter Device",
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        await TokenStorage.saveAccessToken(data["accessToken"]);
        await TokenStorage.saveRefreshToken(data["refreshToken"]);

        await DeviceService.registerDevice();

        return true;
      }

      return false;
    } catch (e) {
      debugPrint("Register error: $e");
      return false;
    }
  }

  static Future<bool> sendOtp(String email) async {
    try {
      final response = await dio.post("/auth/send-otp", data: {"email": email});

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Send OTP Error: $e");
      return false;
    }
  }

  static Future<bool> verifyOtp(String email, String otp) async {
    try {
      final response = await dio.post(
        "/auth/verify-otp",
        data: {"email": email, "otp": otp},
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Verify OTP Error: $e");
      return false;
    }
  }

  static Future<bool> resetPassword(String email, String password) async {
    try {
      final response = await dio.post(
        "/auth/reset-password",
        data: {"email": email, "password": password},
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Reset Password Error: $e");
      return false;
    }
  }
}
