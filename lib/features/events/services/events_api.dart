import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../auth/services/auth_service.dart';

class EventApi {
  // Reuse the shared Dio instance — gets all auth interceptors for free
  static Dio dio = AuthService.dio;

  /// Fetches events from GET /v1/alerts.
  ///
  /// Gated by event:read on the backend — all roles (SuperAdmin, Command Center,
  /// Authority, Organisation) have this permission, matching BRD §4.1/§4.2/§4.3.
  static Future<Map<String, dynamic>> getAlerts({int count = 100}) async {
    final response = await dio.get(
      AppConstants.endpointAlerts,
      queryParameters: {'count': count},
    );

    return response.data;
  }
}
