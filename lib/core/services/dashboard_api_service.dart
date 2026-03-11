import 'dart:convert';
import 'package:alert_dashboard/features/auth/services/token_storage.dart';
import 'package:http/http.dart' as http;
import '../models/dashboard_kpi_model.dart';


class DashboardApiService {

  static Future<DashboardKpiModel> fetchDashboardData() async {

    String? token = await TokenStorage.getAccessToken();

    final response = await http.get(
      Uri.parse("https://your-api-url/dashboard"),
      headers: {
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