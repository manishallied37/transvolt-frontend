import 'dart:io';
import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../auth/services/auth_service.dart';

class EscalationApi {
  static Dio dio = AuthService.dio;
  String get baseUrl => dio.options.baseUrl;

  Future createEscalation(
    Map<String, dynamic> data,
    List<File> files, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final formData = FormData.fromMap(data);

    for (final file in files) {
      formData.files.add(
        MapEntry('files', await MultipartFile.fromFile(file.path)),
      );
    }

    final response = await dio.post(
      AppConstants.apiEscalations,
      data: formData,
      onSendProgress: onSendProgress,
    );
    return response.data;
  }

  Future getEscalations({
    int page = 1,
    int limit = 20,
    String? status,
    String? dateRange,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
      if (dateRange == 'Today') 'dateRange': 'today',
      if (dateRange == 'Last 7 days') 'dateRange': '7d',
      if (dateRange == 'Last 30 days') 'dateRange': '30d',
    };

    final response = await dio.get(
      AppConstants.apiEscalations,
      queryParameters: queryParams,
    );
    return response.data;
  }

  Future getEscalationById(String id) async {
    final response = await dio.get('${AppConstants.apiEscalations}/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> updateEscalationStatus(
    String id,
    String status,
  ) async {
    final response = await dio.patch(
      '${AppConstants.apiEscalations}/$id/status',
      data: {'status': status},
    );
    if (response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'Failed to update status');
    }
    return response.data;
  }

  Future addEscalationComment(
    String escalationId,
    String comment, {
    String commentType = 'GENERAL',
    String? statusChangedTo,
  }) async {
    final response = await dio.post(
      '${AppConstants.apiEscalations}/$escalationId/comments',
      data: {
        'comment': comment,
        'comment_type': commentType,
        if (statusChangedTo != null) 'status_changed_to': statusChangedTo,
      },
    );
    return response.data;
  }
}
