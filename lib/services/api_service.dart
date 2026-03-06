import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import 'auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String baseUrl = dotenv.env['API_URL']!;

  static Future getDashboard() async {
    String? token = await TokenStorage.getAccessToken();

    http.Response response = await http.get(
      Uri.parse("$baseUrl/dashboard"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 401) {
      bool refreshed = await AuthService.refreshAccessToken();

      if (refreshed) {
        String? newToken = await TokenStorage.getAccessToken();

        response = await http.get(
          Uri.parse("$baseUrl/dashboard"),
          headers: {"Authorization": "Bearer $newToken"},
        );
      } else {
        throw Exception("Session expired. Please login again.");
      }
    }

    return jsonDecode(response.body);
  }
}
