class DownloadedMediaItem {
  final String id;
  final int eventId;
  final String title;
  final String type; // image or video
  final String remoteUrl;
  final String localPath;
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'title': title,
      'type': type,
      'remoteUrl': remoteUrl,
      'localPath': localPath,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }

  factory DownloadedMediaItem.fromJson(Map<String, dynamic> json) {
    return DownloadedMediaItem(
      id: json['id'],
      eventId: json['eventId'],
      title: json['title'],
      type: json['type'],
      remoteUrl: json['remoteUrl'],
      localPath: json['localPath'],
      downloadedAt: DateTime.parse(json['downloadedAt']),
    );
  }
}
