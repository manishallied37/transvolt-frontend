import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/auth_service.dart';
import '../../../services/token_storage.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class EventApi {
  static String baseUrl = dotenv.env['API_URL']!;

  /// NEW: Bulk alerts POST /api/alerts
  /// Returns a Map with { "count": n, "data": [ ...alerts ] }
  static Future<Map<String, dynamic>> getAlerts({
    int count = 2,
    String? type,
    Map<String, dynamic>? overrides,
  }) async {
    String? token = await TokenStorage.getAccessToken();

    final Uri url = Uri.parse("$baseUrl/api/alerts");

    Map<String, dynamic> body = {
      "count": count,
      if (type != null && type.isNotEmpty) "type": type,
      if (overrides != null) "overrides": overrides,
    };

    http.Response response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    // Refresh on 401
    if (response.statusCode == 401) {
      bool refreshed = await AuthService.refreshAccessToken();

      if (refreshed) {
        String? newToken = await TokenStorage.getAccessToken();

        response = await http.post(
          url,
          headers: {
            "Authorization": "Bearer $newToken",
            "Content-Type": "application/json",
          },
          body: jsonEncode(body),
        );
      } else {
        throw Exception("Session expired. Please login again.");
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        throw Exception("Unexpected response shape from /api/alerts");
      }
    } else {
      throw Exception("Failed to load alerts: ${response.statusCode}");
    }
  }
}
