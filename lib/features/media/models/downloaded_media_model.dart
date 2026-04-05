import 'dart:io';

class DownloadedMediaItem {
  final String id;
  final int eventId;
  final String title;
  final String type; // 'image' or 'video'
  final String remoteUrl;
  final String localPath; // external storage path or content:// URI
  final DateTime downloadedAt;

  DownloadedMediaItem({
    required this.id,
    required this.eventId,
    required this.title,
    required this.type,
    required this.remoteUrl,
    required this.localPath,
    required this.downloadedAt,
  });

  /// Returns true when the file is confirmed to exist on device storage.
  /// content:// MediaStore URIs cannot be stat-checked synchronously, so they
  /// are assumed present (DownloadService verifies them asynchronously).
  bool get existsOnDevice {
    if (localPath.startsWith('content://')) return true;
    try {
      return File(localPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'title': title,
    'type': type,
    'remoteUrl': remoteUrl,
    'localPath': localPath,
    'downloadedAt': downloadedAt.toIso8601String(),
  };

  factory DownloadedMediaItem.fromJson(Map<String, dynamic> json) =>
      DownloadedMediaItem(
        id: json['id'] as String,
        eventId: json['eventId'] as int,
        title: json['title'] as String,
        type: json['type'] as String,
        remoteUrl: json['remoteUrl'] as String,
        localPath: json['localPath'] as String,
        downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      );
}
