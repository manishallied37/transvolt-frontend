import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:transvolt_fleet/features/auth/services/token_storage.dart';
import '../models/dashboard_kpi_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DashboardApiService {
  static String baseUrl = dotenv.env['API_URL']!;

  static Future<DashboardKpiModel> fetchDashboardData() async {
    String? token = await TokenStorage.getAccessToken();

    final response = await http.get(
      Uri.parse("$baseUrl/dashboard/metrics"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return DashboardKpiModel.fromJson(data);
    } else {
      throw Exception("Failed to load dashboard data");
    }
  }
}
