import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../auth/services/auth_service.dart';
import '../../auth/services/token_storage.dart';

class LivestreamApi {
  LivestreamApi._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['API_URL']!,
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  static const String _tenantUniqueName = 'transvolt';

  static Future<Map<String, dynamic>> _authorizedGet(String path) async {
    final token = await TokenStorage.getAccessToken();

    try {
      final response = await _dio.get(
        path,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        final refreshed = await AuthService.refreshAccessToken();
        if (refreshed) {
          final newToken = await TokenStorage.getAccessToken();
          final retry = await _dio.get(
            path,
            options: Options(headers: {'Authorization': 'Bearer $newToken'}),
          );
          return Map<String, dynamic>.from(retry.data as Map);
        }
      }
      throw Exception(_extractErrorMessage(error));
    }
  }

  static Future<Map<String, dynamic>> _authorizedPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await TokenStorage.getAccessToken();

    try {
      final response = await _dio.post(
        path,
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      // Issue 1 fix: the backend returns 409 when a stream is already active
      // for this vehicle.  The response body still contains valid
      // liveStreamingHlsUrls — return them as-is so the caller can play the
      // stream instead of showing an error.
      if (error.response?.statusCode == 409) {
        final responseData = error.response?.data;
        if (responseData is Map) {
          return Map<String, dynamic>.from(responseData);
        }
      }

      if (error.response?.statusCode == 401) {
        final refreshed = await AuthService.refreshAccessToken();
        if (refreshed) {
          final newToken = await TokenStorage.getAccessToken();
          final retry = await _dio.post(
            path,
            data: body,
            options: Options(headers: {'Authorization': 'Bearer $newToken'}),
          );
          return Map<String, dynamic>.from(retry.data as Map);
        }
      }
      throw Exception(_extractErrorMessage(error));
    }
  }

  static Future<Map<String, dynamic>> getQuota() {
    return _authorizedGet(
      '/netradyne/v1/tenants/$_tenantUniqueName/requests/live/stream/remaining',
    );
  }

  static Future<Map<String, dynamic>> createHlsStream({
    required List<int> cameraPositions,
    required Map<String, dynamic> vehicle,
    required String cameraId,
  }) async {
    await getQuota();

    return _authorizedPost(
      '/netradyne/v1/tenants/$_tenantUniqueName/requests/live/stream/hlsUrl',
      {
        'cameraPosition': cameraPositions,
        'vehicle': vehicle,
        'camera': {'id': cameraId},
        'duration': 60000,
      },
    );
  }

  static String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return error.message ?? 'Failed to start livestream.';
  }
}
