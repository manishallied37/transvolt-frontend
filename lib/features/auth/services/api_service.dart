import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import 'auth_service.dart';

class ApiService {
  static Dio dio = AuthService.dio;

  static Future getDashboard() async {
    try {
      final response = await dio.get(AppConstants.endpointDashboardMetrics);
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data ?? e.message);
    }
  }
}
