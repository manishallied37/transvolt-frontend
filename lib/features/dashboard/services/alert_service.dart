import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../auth/services/auth_service.dart';
import '../models/alert_model.dart';

class AlertService {
  // Reuse the shared Dio instance — gets all auth interceptors for free
  static Dio dio = AuthService.dio;

  static Future<List<AlertModel>> fetchAlerts({int count = 50}) async {
    final response = await dio.post(
      AppConstants.endpointAlertGenerate,
      data: {'count': count},
    );

    final List alerts = response.data['data'];
    return alerts.map((e) => AlertModel.fromJson(e)).toList();
  }
}
