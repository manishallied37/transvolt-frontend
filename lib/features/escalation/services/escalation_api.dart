import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EscalationApi {
  final Dio dio = Dio(BaseOptions(baseUrl: "${dotenv.env['API_URL']}/api"));
  String get baseUrl => dio.options.baseUrl;

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
      "/escalations",
      data: formData,
      onSendProgress: onSendProgress, // <-- add this
    );

    return response.data;
  }

  /// GET ALL ESCALATIONS
  Future getEscalations() async {
    final response = await dio.get("/escalations");

    return response.data;
  }

  /// GET SINGLE ESCALATION
  Future getEscalationById(String id) async {
    final response = await dio.get("/escalations/$id");

    return response.data;
  }

  /// UPDATE STATUS
  Future<Map<String, dynamic>> updateEscalationStatus(
    String id,
    String status,
  ) async {
    final response = await dio.patch(
      '/escalations/$id/status',
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
      '/escalations/$escalationId/comments',
      data: {
        'comment': comment,
        'comment_type': commentType,
        if (statusChangedTo != null) 'status_changed_to': statusChangedTo,
      },
    );
    return response.data;
  }
}
