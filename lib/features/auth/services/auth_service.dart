import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'token_storage.dart';
import 'device_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static String baseUrl = dotenv.env['API_URL']!;
  static Dio dio = Dio(BaseOptions(baseUrl: baseUrl));

  static void setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path.contains("/auth/login") ||
              options.path.contains("/auth/register") ||
              options.path.contains("/auth/send-otp") ||
              options.path.contains("/auth/verify-otp") ||
              options.path.contains("/auth/refresh") ||
              options.path.contains("/auth/verify-login-otp")) {
            return handler.next(options);
          }

          final token = await TokenStorage.getAccessToken();

          if (token != null) {
            options.headers["Authorization"] = "Bearer $token";
          }

          handler.next(options);
        },

        onError: (DioException e, handler) async {
          if (e.requestOptions.path.contains("/auth/refresh")) {
            return handler.next(e);
          }

          if (e.requestOptions.path.contains("/auth/logout")) {
            return handler.next(e);
          }

          if (e.response?.statusCode == 401) {
            bool refreshed = await AuthService.refreshAccessToken();

            if (refreshed) {
              final token = await TokenStorage.getAccessToken();
              e.requestOptions.headers["Authorization"] = "Bearer $token";

              final response = await dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } else {
              await TokenStorage.clearTokens();
            }
          }

          handler.next(e);
        },
      ),
    );
  }

  static Future<Map<String, dynamic>?> login(
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
        return response.data;
      }

      return null;
    } catch (e) {
      if (e is DioException) {
        debugPrint("STATUS: ${e.response?.statusCode}");
        debugPrint("DATA: ${e.response?.data}");
      } else {
        debugPrint("ERROR: $e");
      }
    }
    return null;
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
    String mobileNumber,
  ) async {
    try {
      final body = {
        "username": username,
        "email": email,
        "password": password,
        "role": role,
        "region": region,
        "depot": depot,
        "deviceId": deviceId,
        "deviceName": "Flutter Device",
        "mobile_number": mobileNumber,
      };

      debugPrint("REGISTER BODY: $body");

      final response = await dio.post("/auth/register", data: body);

      debugPrint("REGISTER RESPONSE: ${response.data}");

      if (response.statusCode == 201) {
        final data = response.data;

        await TokenStorage.saveAccessToken(data["tokens"]["accessToken"]);
        await TokenStorage.saveRefreshToken(data["tokens"]["refreshToken"]);

        await DeviceService.registerDevice();

        return true;
      }

      return false;
    } catch (e) {
      if (e is DioException) {
        debugPrint("REGISTER ERROR:");
        debugPrint("STATUS: ${e.response?.statusCode}");
        debugPrint("DATA: ${e.response?.data}");
      } else {
        debugPrint("UNKNOWN ERROR: $e");
      }
      return false;
    }
  }

  static Future<bool> sendOtp(String identifier, String method) async {
    try {
      final response = await dio.post(
        "/auth/send-otp",
        data: {"identifier": identifier, "method": method},
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Send OTP Error: $e");
      return false;
    }
  }

  static Future<bool> verifyOtp(
    String identifier,
    String otp,
    String method,
  ) async {
    try {
      final response = await dio.post(
        "/auth/verify-otp",
        data: {"identifier": identifier, "otp": otp, "method": method},
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Verify OTP Error: $e");
      return false;
    }
  }

  static Future<bool> resetPassword(
    String identifier,
    String password,
    String method,
  ) async {
    try {
      final response = await dio.post(
        "/auth/reset-password",
        data: {
          "identifier": identifier,
          "password": password,
          "method": method,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Reset Password Error: $e");
      return false;
    }
  }

  static Future<bool> verifyLoginOtp(
    String identifier,
    String otp,
    String deviceId,
  ) async {
    try {
      final response = await dio.post(
        "/auth/verify-login-otp",
        data: {"identifier": identifier, "otp": otp, "deviceId": deviceId},
      );

      if (response.statusCode == 200) {
        final data = response.data;

        await TokenStorage.saveAccessToken(data["tokens"]["accessToken"]);
        await TokenStorage.saveRefreshToken(data["tokens"]["refreshToken"]);

        return true;
      }

      return false;
    } catch (e) {
      if (e is DioException) {
        debugPrint("Server Response: ${e.response?.data}");
      }
      debugPrint("Verify Login OTP Error: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    try {
      await dio.post("/auth/logout");
    } catch (_) {}

    await TokenStorage.clearTokens();
  }

  static Future<void> logoutAllDevices() async {
    await dio.post("/auth/logout-all");

    await TokenStorage.clearTokens();
  }
}
