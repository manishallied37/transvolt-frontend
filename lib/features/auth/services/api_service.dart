import 'package:dio/dio.dart';
import 'auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String baseUrl = dotenv.env['API_URL']!;
  static Dio dio = AuthService.dio;

  static Future getDashboard() async {
    try {
      Response response = await dio.get("/dashboard");

      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data ?? e.message);
    }
  }
}
