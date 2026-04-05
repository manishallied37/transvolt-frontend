import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../auth/services/auth_service.dart';
import '../../auth/services/token_storage.dart';

class VehicleService {
  VehicleService._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['API_URL']!,
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  static const String _tenantUniqueName = 'transvolt';

  static Future<List<Map<String, dynamic>>> getVehicles() async {
    final token = await TokenStorage.getAccessToken();

    final response = await _dio.get(
      '/netradyne/v1/tenants/$_tenantUniqueName/vehicles',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
  }
}
