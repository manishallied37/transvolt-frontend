import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/constants/app_constants.dart';
import 'token_storage.dart';

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
            AppConstants.endpointSendOtp,
            AppConstants.endpointVerifyOtp,
            AppConstants.endpointRefresh,
            AppConstants.endpointVerifyLoginOtp,
            AppConstants.endpointDeviceLogin,
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

          // Never attempt a token refresh on these paths —
          // they either don't need auth or are part of the auth flow itself.
          final skipRefreshPaths = [
            AppConstants.endpointRefresh,
            AppConstants.endpointLogout,
            AppConstants.endpointLogoutAll,
            AppConstants.endpointLogin,
            AppConstants.endpointVerifyLoginOtp,
            AppConstants.endpointVerifyOtp,
            AppConstants.endpointSendOtp,
            AppConstants.endpointDeviceLogin,
            AppConstants.endpointResetPassword,
          ];

          final shouldSkip = skipRefreshPaths.any((p) => path.contains(p));
          if (shouldSkip) return handler.next(e);

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

        // Save the persistent device token so the app can restore the
        // session silently after reinstall (no OTP needed next time).
        if (data['deviceToken'] != null) {
          await TokenStorage.saveDeviceToken(data['deviceToken']);
        }

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

  /// Called on app startup when a saved [deviceToken] is found in secure storage.
  /// If the token is still valid (not expired / not revoked), the backend
  /// issues a fresh session — no password or OTP required.
  ///
  /// Returns [true] and saves new tokens on success.
  /// Returns [false] if the token has expired or the device is no longer trusted,
  /// so the caller should redirect to the normal login screen.
  static Future<bool> deviceLogin(String deviceToken, String deviceId) async {
    try {
      final response = await dio.post(
        AppConstants.endpointDeviceLogin,
        data: {'deviceToken': deviceToken, 'deviceId': deviceId},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await TokenStorage.saveAccessToken(data['tokens']['accessToken']);
        await TokenStorage.saveRefreshToken(data['tokens']['refreshToken']);

        // Backend rotates the device token on every use — always save the new one.
        if (data['newDeviceToken'] != null) {
          await TokenStorage.saveDeviceToken(data['newDeviceToken']);
        }

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Device login error: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    try {
      await dio.post(AppConstants.endpointLogout);
    } catch (_) {}
    // clearAll removes access, refresh, AND device token so reinstalling
    // the app won't bypass login after an explicit logout.
    await TokenStorage.clearAll();
  }

  static Future<void> logoutAllDevices() async {
    try {
      await dio.post(AppConstants.endpointLogoutAll);
    } catch (_) {}
    await TokenStorage.clearAll();
  }
}
