import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../auth/services/token_storage.dart';
import '../../auth/services/auth_service.dart';

import '../models/alert_model.dart';

class AlertService {

  static String baseUrl = dotenv.env["API_URL"]!;

  static Dio dio = Dio(BaseOptions(baseUrl: baseUrl));

  static Future<List<AlertModel>> fetchAlerts({int count = 50}) async {

    String? token = await TokenStorage.getAccessToken();

    Map<String, dynamic> body = {
      "count": count,
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

      List alerts = response.data["data"];

      return alerts.map((e) => AlertModel.fromJson(e)).toList();

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

          List alerts = retryResponse.data["data"];

          return alerts.map((e) => AlertModel.fromJson(e)).toList();

        } else {

          throw Exception("Session expired. Please login again.");

        }
      }

      throw Exception("API error: ${e.message}");
    }
  }
}