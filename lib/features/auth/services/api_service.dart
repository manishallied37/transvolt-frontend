import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import 'auth_service.dart';

class ApiService {
  static Dio dio = AuthService.dio;

  /// Fetches the dashboard metrics for the current user.
  /// Throws a descriptive [Exception] if the request fails.
  static Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await dio.get(AppConstants.endpointDashboardMetrics);
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Unexpected response format from dashboard API');
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message)
          : e.message;
      throw Exception('Dashboard API error: $message');
    }
  }
}
