import 'package:flutter/material.dart';

class MediaDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> mediaDetailsArray;

  const MediaDetailsScreen({super.key, required this.mediaDetailsArray});

  @override
  Widget build(BuildContext context) {
    debugPrint(mediaDetailsArray.toString()); // access full event data

    return Scaffold(
      appBar: AppBar(title: const Text("Media Details")),
      body: Center(child: Text("Event ID: ${mediaDetailsArray['id']}")),
    );
  }
}
