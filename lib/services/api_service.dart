import 'package:dio/dio.dart';
import 'token_storage.dart';
import 'auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String baseUrl = dotenv.env['API_URL']!;
  static Dio dio = Dio(BaseOptions(baseUrl: baseUrl));

  static Future getDashboard() async {
    String? token = await TokenStorage.getAccessToken();

    Response response = await dio.get(
      "/dashboard",
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );

    if (response.statusCode == 401) {
      bool refreshed = await AuthService.refreshAccessToken();

      if (refreshed) {
        String? newToken = await TokenStorage.getAccessToken();

        response = await dio.get(
          "/dashboard",
          options: Options(headers: {"Authorization": "Bearer $newToken"}),
        );
      } else {
        throw Exception("Session expired. Please login again.");
      }
    }

    return response.data;
  }
}
