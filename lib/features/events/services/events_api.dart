import '../../auth/services/auth_service.dart';
import '../../auth/services/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EventApi {
  static String baseUrl = dotenv.env['API_URL']!;
  static Dio dio = Dio(BaseOptions(baseUrl: baseUrl));

  static Future<Map<String, dynamic>> getAlerts({
    int count = 2,
    String? type,
    Map<String, dynamic>? overrides,
  }) async {
    String? token = await TokenStorage.getAccessToken();

    Map<String, dynamic> body = {
      "count": count,
      if (type != null && type.isNotEmpty) "type": type,
      if (overrides != null) "overrides": overrides,
    };

    try {
      Response response = await dio.post(
        "/auth/api/alerts",
        data: body,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        ),
      );

      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        bool refreshed = await AuthService.refreshAccessToken();

        if (refreshed) {
          String? newToken = await TokenStorage.getAccessToken();

          Response retryResponse = await dio.post(
            "/auth/api/alerts",
            data: body,
            options: Options(
              headers: {
                "Authorization": "Bearer $newToken",
                "Content-Type": "application/json",
              },
            ),
          );

          return retryResponse.data;
        } else {
          throw Exception("Session expired. Please login again.");
        }
      }

      throw Exception("API error: ${e.message}");
    }
  }
}
