class EventItem {
  final int id;
  final String title;
  final String eventType;
  final String severity;
  final String vehicleId;
  final String driverName;
  final String depot;
  final String status;
  final String timestamp;
  final String location;
  final String? thumbnailUrl;
  final String description;
  final int? netradyneAlertId;

  EventItem({
    required this.id,
    required this.title,
    required this.eventType,
    required this.severity,
    required this.vehicleId,
    required this.driverName,
    required this.depot,
    required this.status,
    required this.timestamp,
    required this.location,
    required this.thumbnailUrl,
    required this.description,
    required this.netradyneAlertId,
  });

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: _toInt(json['id']) ?? 0,
      title: _toStr(json['title']),
      eventType: _toStr(json['eventType']),
      severity: _toStr(json['severity']),
      vehicleId: _toStr(json['vehicleId']),
      driverName: _toStr(json['driverName']),
      depot: _toStr(json['depot']),
      status: _toStr(json['status']),
      timestamp: _toStr(json['timestamp']),
      location: _toStr(json['location']),
      thumbnailUrl: _toNullableStr(json['thumbnailUrl']),
      description: _toStr(json['description']),
      netradyneAlertId: _toInt(json['netradyneAlertId']),
    );
  }

  EventItem copyWith({
    int? id,
    String? title,
    String? eventType,
    String? severity,
    String? vehicleId,
    String? driverName,
    String? depot,
    String? status,
    String? timestamp,
    String? location,
    String? thumbnailUrl,
    String? description,
    int? netradyneAlertId,
  }) {
    return EventItem(
      id: id ?? this.id,
      title: title ?? this.title,
      eventType: eventType ?? this.eventType,
      severity: severity ?? this.severity,
      vehicleId: vehicleId ?? this.vehicleId,
      driverName: driverName ?? this.driverName,
      depot: depot ?? this.depot,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      description: description ?? this.description,
      netradyneAlertId: netradyneAlertId ?? this.netradyneAlertId,
    );
  }
}

class MediaItem {
  final int id;
  final String type;
  final String title;
  final String url;
  final String? thumbnailUrl;
  final String? mimeType;
  final String? source;

  MediaItem({
    required this.id,
    required this.type,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    required this.mimeType,
    required this.source,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: _toInt(json['id']) ?? 0,
      type: _toStr(json['type']),
      title: _toStr(json['title']),
      url: _firstNonEmpty([
        json['url'],
        json['imageUrl'],
        json['videoUrl'],
        json['thumbnailUrl'],
        json['videoplayurl'],
        json['playUrl'],
      ]),
      thumbnailUrl: _firstNullableNonEmpty([
        json['thumbnailUrl'],
        json['previewUrl'],
        json['imageUrl'],
      ]),
      mimeType: _firstNullableNonEmpty([json['mimeType'], json['contentType']]),
      source: _toNullableStr(json['source']),
    );
  }

  MediaItem copyWith({
    int? id,
    String? type,
    String? title,
    String? url,
    String? thumbnailUrl,
    String? mimeType,
    String? source,
  }) {
    return MediaItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mimeType: mimeType ?? this.mimeType,
      source: source ?? this.source,
    );
  }
}

class EventMediaResponse {
  final EventItem event;
  final List<MediaItem> images;
  final List<MediaItem> videos;

  EventMediaResponse({
    required this.event,
    required this.images,
    required this.videos,
  });

  factory EventMediaResponse.fromJson(Map<String, dynamic> json) {
    return EventMediaResponse(
      event: EventItem.fromJson(
        (json['event'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      images: (json['images'] as List<dynamic>? ?? [])
          .map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      videos: (json['videos'] as List<dynamic>? ?? [])
          .map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  EventMediaResponse copyWith({
    EventItem? event,
    List<MediaItem>? images,
    List<MediaItem>? videos,
  }) {
    return EventMediaResponse(
      event: event ?? this.event,
      images: images ?? this.images,
      videos: videos ?? this.videos,
    );
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString());
}

String _toStr(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

String? _toNullableStr(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = _toNullableStr(value);
    if (text != null) return text;
  }
  return '';
}

String? _firstNullableNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = _toNullableStr(value);
    if (text != null) return text;
  }
  return null;
}
