import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../auth/services/auth_service.dart';

class EscalationApi {
  String baseUrl = dotenv.env['API_URL']!;
  static Dio dio = AuthService.dio;

  /// CREATE ESCALATION (form + evidence)
  Future createEscalation(
    Map<String, dynamic> data,
    List<File> files, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    FormData formData = FormData.fromMap(data);

    for (var file in files) {
      formData.files.add(
        MapEntry("files", await MultipartFile.fromFile(file.path)),
      );
    }

    final response = await dio.post(
      "/api/escalations",
      data: formData,
      onSendProgress: onSendProgress, // <-- add this
    );

    return response.data;
  }

  /// GET ALL ESCALATIONS
  Future getEscalations() async {
    final response = await dio.get("/api/escalations");

    return response.data;
  }

  /// GET SINGLE ESCALATION
  Future getEscalationById(String id) async {
    final response = await dio.get("/api/escalations/$id");

    return response.data;
  }

  /// UPDATE STATUS
  Future<Map<String, dynamic>> updateEscalationStatus(
    String id,
    String status,
  ) async {
    final response = await dio.patch(
      '/api/escalations/$id/status',
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
      '/api/escalations/$escalationId/comments',
      data: {
        'comment': comment,
        'comment_type': commentType,
        if (statusChangedTo != null) 'status_changed_to': statusChangedTo,
      },
    );
    return response.data;
  }
}
