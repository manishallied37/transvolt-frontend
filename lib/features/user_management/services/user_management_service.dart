import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../auth/services/auth_service.dart';

class UserManagementService {
  static Dio get _dio => AuthService.dio;

  /// List all users (paginated). Role scoping is handled by the backend.
  static Future<Map<String, dynamic>> listUsers({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        AppConstants.endpointUsers,
        queryParameters: {'page': page, 'limit': limit},
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to fetch users');
    } catch (e) {
      debugPrint('listUsers error: $e');
      rethrow;
    }
  }

  /// Get single user by id.
  static Future<Map<String, dynamic>> getUserById(int userId) async {
    try {
      final response = await _dio.get('${AppConstants.endpointUsers}/$userId');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('User not found');
    } catch (e) {
      debugPrint('getUserById error: $e');
      rethrow;
    }
  }

  /// Create a new user. SuperAdmin only — enforced on both frontend and backend.
  static Future<Map<String, dynamic>> createUser({
    required String username,
    required String email,
    required String password,
    required String role,
    String? region,
    String? depot,
    String? mobileNumber,
  }) async {
    try {
      final response = await _dio.post(
        AppConstants.endpointUsers,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'role': role,
          if (region != null) 'region': region,
          if (depot != null) 'depot': depot,
          if (mobileNumber != null) 'mobile_number': mobileNumber,
        },
      );
      if (response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to create user');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to create user';
      throw Exception(msg);
    }
  }

  /// Update a user's username, email, region, depot, active status, or mobile number.
  static Future<Map<String, dynamic>> updateUser(
    int userId, {
    bool? isActive,
    String? username,
    String? email,
    String? region,
    String? depot,
    String? mobileNumber,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (isActive != null) data['is_active'] = isActive;
      if (username != null) data['username'] = username;
      if (email != null) data['email'] = email;
      if (region != null) data['region'] = region;
      if (depot != null) data['depot'] = depot;
      if (mobileNumber != null) data['mobile_number'] = mobileNumber;

      final response = await _dio.patch(
        '${AppConstants.endpointUsers}/$userId',
        data: data,
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to update user');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to update user';
      throw Exception(msg);
    }
  }

  /// Change a user's role (SuperAdmin only).
  static Future<Map<String, dynamic>> changeUserRole(
    int userId,
    String newRole,
  ) async {
    try {
      final response = await _dio.patch(
        '${AppConstants.endpointUsers}/$userId/role',
        data: {'role': newRole},
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to change role');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to change role';
      throw Exception(msg);
    }
  }

  /// Deactivate a user (SuperAdmin only — soft delete).
  static Future<void> deactivateUser(int userId) async {
    try {
      final response = await _dio.delete(
        '${AppConstants.endpointUsers}/$userId',
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to deactivate user');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to deactivate user';
      throw Exception(msg);
    }
  }

  /// Get current user's permission list.
  static Future<Map<String, dynamic>> getMyPermissions() async {
    try {
      final response = await _dio.get(AppConstants.endpointMyPermissions);
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to fetch permissions');
    } catch (e) {
      debugPrint('getMyPermissions error: $e');
      rethrow;
    }
  }
}
