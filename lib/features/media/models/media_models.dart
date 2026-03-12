class MediaImage {
  final String id;
  final String url;

  MediaImage({required this.id, required this.url});

  factory MediaImage.fromJson(Map<String, dynamic> json) {
    return MediaImage(
      id: json['id']?.toString() ?? '',
      url: json['url'] ?? json['imageUrl'] ?? json['thumbnailUrl'] ?? '',
    );
  }
}

class MediaVideo {
  final String requestId;
  final String videoUrl;
  final String status;

  MediaVideo({
    required this.requestId,
    required this.videoUrl,
    required this.status,
  });

  factory MediaVideo.fromJson(Map<String, dynamic> json) {
    return MediaVideo(
      requestId: json['requestId'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      status: json['status'] ?? 'pending',
    );
  }
}
