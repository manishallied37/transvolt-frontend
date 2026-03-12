import 'package:flutter/material.dart';
import '../media_module.dart';

class MediaDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> mediaDetailsArray;

  const MediaDetailsScreen({super.key, required this.mediaDetailsArray});

  @override
  Widget build(BuildContext context) {
    debugPrint("Media Details Array: $mediaDetailsArray", wrapWidth: 1024);

    final int eventId = int.parse(mediaDetailsArray['id'].toString());

    debugPrint("Event ID: $eventId");

    return MediaModule(eventId: eventId, alertData: mediaDetailsArray);
  }
}
