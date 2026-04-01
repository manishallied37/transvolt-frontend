import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/constants/app_constants.dart';
import 'token_storage.dart';

class AuthService {
  static String get baseUrl {
    final url = dotenv.env['API_URL'];
    assert(url != null && url.isNotEmpty, 'API_URL is not set in .env file');
    if (url == null || url.isEmpty) {
      debugPrint(
        '[FATAL] API_URL is not set in .env. Using localhost fallback.',
      );
      return 'http://localhost:5000';
    }
    return url;
  }

  static Dio dio = _createDio();

  /// 🔒 Refresh lock
  static bool _refreshing = false;
  static final List<Completer<bool>> _refreshQueue = [];

  static Future<bool> lockedRefresh() async {
    if (_refreshing) {
      final completer = Completer<bool>();
      _refreshQueue.add(completer);
      return completer.future;
    }

    _refreshing = true;

    bool result = false;
    try {
      result = await refreshAccessToken();
    } catch (_) {
      result = false;
    }

    _refreshing = false;

    // Notify all waiting requests
    for (final c in _refreshQueue) {
      if (!c.isCompleted) c.complete(result);
    }
    _refreshQueue.clear();

    return result;
  }

  /// Dio setup
  static Dio _createDio() {
    final dio = Dio(BaseOptions(baseUrl: baseUrl));

    if (kReleaseMode) {
      final httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
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

          // 🔁 Prevent infinite retry
          if (e.requestOptions.extra['retry'] == true) {
            return handler.next(e);
          }

          if (e.response?.statusCode == 401) {
            final refreshed = await lockedRefresh();

            if (refreshed) {
              final token = await TokenStorage.getAccessToken();
              final opts = e.requestOptions;

              // mark request as retried
              opts.extra['retry'] = true;

              // update token
              opts.headers['Authorization'] = 'Bearer $token';

              try {
                final response = await dio.request(
                  opts.path,
                  data: opts.data,
                  queryParameters: opts.queryParameters,
                  options: Options(method: opts.method, headers: opts.headers),
                );

                return handler.resolve(response);
              } catch (err) {
                return handler.next(err is DioException ? err : e);
              }
            } else {
              await TokenStorage.clearAll(); // 🔥 important fix
            }
          }

          handler.next(e);
        },
      ),
    );
  }

  /// ---------------- AUTH APIs ----------------

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

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Login STATUS: ${e.response?.statusCode}');
      debugPrint('Login DATA: ${e.response?.data}');

      final serverMessage = e.response?.data is Map
          ? (e.response!.data['message'] as String?)
          : null;

      throw Exception(serverMessage ?? 'Login failed. Please try again.');
    }
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

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] as String? ?? 'Failed to send OTP')
          : 'Failed to send OTP';

      throw Exception(msg);
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(
    String identifier,
    String otp,
    String method,
  ) async {
    try {
      final response = await dio.post(
        AppConstants.endpointVerifyOtp,
        data: {'identifier': identifier, 'otp': otp, 'method': method},
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception("OTP verification failed");
      }
    } catch (e) {
      debugPrint('Verify OTP error: $e');
      throw Exception("Invalid OTP");
    }
  }

  static Future<bool> resetPassword(
    String identifier,
    String password,
    String method,
    String resetToken,
  ) async {
    try {
      final response = await dio.post(
        AppConstants.endpointResetPassword,
        data: {
          'identifier': identifier,
          'password': password,
          'method': method,
          'resetToken': resetToken,
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

        if (data['deviceToken'] != null) {
          await TokenStorage.saveDeviceToken(data['deviceToken']);
        }

        return true;
      }

      return false;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] as String? ??
                'OTP verification failed')
          : 'OTP verification failed';
      throw Exception(msg);
    }
  }

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

    await TokenStorage.clearAll();
  }

  static Future<void> logoutAllDevices() async {
    try {
      await dio.post(AppConstants.endpointLogoutAll);
    } catch (_) {}

    await TokenStorage.clearAll();
  }
}
