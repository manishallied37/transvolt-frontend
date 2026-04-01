import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../auth/services/auth_service.dart';

class ReportApi {
  static Dio dio = AuthService.dio;

  Future<Response> getAuditReport({
    int page = 1,
    int limit = 20,
    String? action,
    String? startDate,
    String? endDate,
  }) async {
    return await dio.get(
      "${AppConstants.apiReports}/audit",
      queryParameters: {
        'page': page,
        'limit': limit,
        if (action != null) 'action': action,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      },
    );
  }

  Future<Response> exportAuditCSV() async {
    return await dio.get(
      "${AppConstants.apiReports}/audit/export",
      options: Options(responseType: ResponseType.bytes),
    );
  }

  Future<Response> getAuditStats() async {
    return await dio.get("${AppConstants.apiReports}/audit/stats");
  }
}
