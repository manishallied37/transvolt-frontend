import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';
import '../services/report_api.dart';

Future<void> downloadCSV(BuildContext context) async {
  try {
    final api = ReportApi();

    final response = await api.exportAuditCSV();

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/audit_report.csv");

    await file.writeAsBytes(response.data);

    final result = await OpenFilex.open(file.path);

    if (!context.mounted) return;

    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File saved but cannot open")),
      );
    }
  } catch (e) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Download failed")));
  }
}
