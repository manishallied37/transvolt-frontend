import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EvidenceUploadScreen extends StatefulWidget {
  final String escalationId;

  const EvidenceUploadScreen({super.key, required this.escalationId});

  @override
  State<EvidenceUploadScreen> createState() => _EvidenceUploadScreenState();
}

class _EvidenceUploadScreenState extends State<EvidenceUploadScreen> {
  File? selectedFile;

  final Dio dio = Dio(BaseOptions(baseUrl: "${dotenv.env['API_URL']}/api"));
  String get baseUrl => dio.options.baseUrl;

  Future pickFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future uploadFile() async {
    if (selectedFile == null) return;

    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(selectedFile!.path),
    });

    final response = await dio.post(
      "/escalations/${widget.escalationId}/evidence",
      data: formData,
    );

    if (response.data["success"]) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Escalation submitted successfully")),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        "/dashboard",
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attach Evidence")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            ElevatedButton(
              onPressed: pickFile,
              child: const Text("Select File"),
            ),

            const SizedBox(height: 20),

            if (selectedFile != null) Text(selectedFile!.path),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: uploadFile,
              child: const Text("Submit Escalation"),
            ),
          ],
        ),
      ),
    );
  }
}
