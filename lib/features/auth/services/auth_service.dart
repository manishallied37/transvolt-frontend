import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/constants/app_constants.dart';
import 'token_storage.dart';
import 'device_service.dart';

class AuthService {
  static String baseUrl = dotenv.env['API_URL']!;
  static Dio dio = _createDio();

  /// In production, reject any certificate that doesn't match our hostname.
  /// In debug/test, allow all certificates so local dev servers work.
  static Dio _createDio() {
    final dio = Dio(BaseOptions(baseUrl: baseUrl));

    if (kReleaseMode) {
      final httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              // Only allow our own API domain
              final allowedHost = Uri.parse(baseUrl).host;
              final isAllowed = host == allowedHost;
              if (!isAllowed) {
                debugPrint('[Security] Rejected certificate for host: $host');
              }
              return isAllowed;
            };

      (dio.httpClientAdapter as dynamic).onHttpClientCreate = (_) => httpClient;
    }

    return dio;
  }

  static void setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Public auth paths — no token needed
          final publicPaths = [
            AppConstants.endpointLogin,
            AppConstants.endpointRegister,
            AppConstants.endpointSendOtp,
            AppConstants.endpointVerifyOtp,
            AppConstants.endpointRefresh,
            AppConstants.endpointVerifyLoginOtp,
          ];

          final isPublic = publicPaths.any((p) => options.path.contains(p));
          if (isPublic) return handler.next(options);

          final token = await TokenStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },

        onError: (DioException e, handler) async {
          final path = e.requestOptions.path;

          if (path.contains(AppConstants.endpointRefresh)) {
            return handler.next(e);
          }
          if (path.contains(AppConstants.endpointLogout)) {
            return handler.next(e);
          }

          if (e.response?.statusCode == 401) {
            final refreshed = await AuthService.refreshAccessToken();

            if (refreshed) {
              final token = await TokenStorage.getAccessToken();
              e.requestOptions.headers['Authorization'] = 'Bearer $token';
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
        AppConstants.endpointLogin,
        data: {'login': login, 'password': password, 'deviceId': deviceId},
      );
      if (response.statusCode == 200) return response.data;
      return null;
    } catch (e) {
      if (e is DioException) {
        debugPrint('Login STATUS: ${e.response?.statusCode}');
        debugPrint('Login DATA: ${e.response?.data}');
      } else {
        debugPrint('Login ERROR: $e');
      }
    }
    return null;
  }

  static Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await dio.post(
        AppConstants.endpointRefresh,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await TokenStorage.saveAccessToken(data['accessToken']);
        if (data['refreshToken'] != null) {
          await TokenStorage.saveRefreshToken(data['refreshToken']);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Refresh token error: $e');
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
      final response = await dio.post(
        AppConstants.endpointRegister,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'role': role,
          'region': region,
          'depot': depot,
          'deviceId': deviceId,
          'deviceName': 'Flutter Device',
          'mobile_number': mobileNumber,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        await TokenStorage.saveAccessToken(data['tokens']['accessToken']);
        await TokenStorage.saveRefreshToken(data['tokens']['refreshToken']);
        await DeviceService.registerDevice();
        return true;
      }
      return false;
    } catch (e) {
      if (e is DioException) {
        debugPrint('Register STATUS: ${e.response?.statusCode}');
        debugPrint('Register DATA: ${e.response?.data}');
      } else {
        debugPrint('Register ERROR: $e');
      }
      return false;
    }
  }

  static Future<bool> sendOtp(String identifier, String method) async {
    try {
      final response = await dio.post(
        AppConstants.endpointSendOtp,
        data: {'identifier': identifier, 'method': method},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Send OTP error: $e');
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
        AppConstants.endpointVerifyOtp,
        data: {'identifier': identifier, 'otp': otp, 'method': method},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Verify OTP error: $e');
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
        AppConstants.endpointResetPassword,
        data: {
          'identifier': identifier,
          'password': password,
          'method': method,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Reset password error: $e');
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
        AppConstants.endpointVerifyLoginOtp,
        data: {'identifier': identifier, 'otp': otp, 'deviceId': deviceId},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await TokenStorage.saveAccessToken(data['tokens']['accessToken']);
        await TokenStorage.saveRefreshToken(data['tokens']['refreshToken']);
        return true;
      }
      return false;
    } catch (e) {
      if (e is DioException) {
        debugPrint('Verify login OTP server response: ${e.response?.data}');
      }
      debugPrint('Verify login OTP error: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    try {
      await dio.post(AppConstants.endpointLogout);
    } catch (_) {}
    await TokenStorage.clearTokens();
  }

  static Future<void> logoutAllDevices() async {
    try {
      await dio.post(AppConstants.endpointLogoutAll);
    } catch (_) {}
    await TokenStorage.clearTokens();
  }
}
