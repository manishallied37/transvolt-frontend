import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

class ApiService {
  static const baseUrl = "http://192.168.0.66:5000";

  static Future getDashboard() async {
    String? token = await TokenStorage.getAccessToken();

    final response = await http.get(
      Uri.parse("$baseUrl/dashboard"),
      headers: {"Authorization": "Bearer $token"},
    );

    return jsonDecode(response.body);
  }
}
