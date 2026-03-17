import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../features/auth/services/auth_service.dart';
import '../models/dashboard_kpi_model.dart';

class DashboardApiService {
  static Dio dio = AuthService.dio;

  static Future<DashboardKpiModel> fetchDashboardData() async {
    final response = await dio.get(AppConstants.endpointDashboardMetrics);

    return DashboardKpiModel.fromJson(response.data["metrics"]);
  }
}
