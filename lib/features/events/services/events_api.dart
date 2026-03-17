import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../auth/services/auth_service.dart';

class EventApi {
  // Reuse the shared Dio instance — gets all auth interceptors for free
  static Dio dio = AuthService.dio;

  static Future<Map<String, dynamic>> getAlerts({
    int count = 2,
    String? type,
    Map<String, dynamic>? overrides,
  }) async {
    final body = {
      'count': count,
      if (type != null && type.isNotEmpty) 'type': type,
      if (overrides != null) 'overrides': overrides,
    };

    final response = await dio.post(
      AppConstants.endpointAlertGenerate,
      data: body,
    );

    return response.data;
  }
}
