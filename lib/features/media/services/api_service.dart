import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/event_models.dart';
import '../../auth/services/auth_service.dart';

class ApiService {
  static String baseUrl = dotenv.env['API_URL']!;

  // Reuse the shared Dio instance with interceptors
  static Dio dio = AuthService.dio;

  static Future<Response> _authorizedGetUri(Uri uri) async {
    debugPrint('[API] GET ${uri.toString()}');
    final response = await dio.getUri(uri);
    debugPrint(
      '[API] RESPONSE ${response.statusCode} for GET ${uri.toString()}',
    );
    return response;
  }

  static Future<Response> _authorizedGet(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    return _authorizedGetUri(uri);
  }

  /// ===== GET EVENTS =====
  static Future<List<EventItem>> getEvents() async {
    final response = await _authorizedGet('/v1/events');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch events (${response.statusCode}): ${response.data}',
      );
    }

    final decoded = response.data;

    if (decoded is List) {
      return decoded
          .map((item) => EventItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      final events = decoded['events'] as List<dynamic>? ?? [];

      return events
          .map((item) => EventItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Unexpected events response format');
  }

  /// ===== GET EVENT MEDIA USING ONLY 2 MOCK APIS =====
  static Future<EventMediaResponse> getEventMedia(
    int eventId,
    Map<String, dynamic> alertData,
  ) async {
    debugPrint('[UI ACTION] View Media clicked for eventId=$eventId');

    final tenant = (alertData['tenantName'] ?? 'demo').toString().trim().isEmpty
        ? 'demo'
        : alertData['tenantName'].toString().trim();

    final timestamp =
        _toInt(alertData['timestamp']) ?? DateTime.now().millisecondsSinceEpoch;
    final durationMs = ((_toInt(alertData['duration']) ?? 60) * 1000);
    final endTime = timestamp + durationMs;

    final vehicle =
        (alertData['vehicle'] as Map?)?.cast<String, dynamic>() ?? {};
    final driver = (alertData['driver'] as Map?)?.cast<String, dynamic>() ?? {};
    final details =
        (alertData['details'] as Map?)?.cast<String, dynamic>() ?? {};
    final location =
        (details['location'] as Map?)?.cast<String, dynamic>() ?? {};
    final videos = (alertData['videos'] as List?) ?? const [];

    final vehicleNumber = (vehicle['vehicleNumber'] ?? '').toString();
    final vin = (vehicle['vin'] ?? '').toString();
    final licensePlateNumber = (vehicle['licensePlateNumber'] ?? '').toString();

    final driverName =
        '${(driver['firstName'] ?? '').toString()} ${(driver['lastName'] ?? '').toString()}'
            .trim();

    final alertType = (details['typeDescription'] ?? '').toString();
    final severity = (details['severityDescription'] ?? '').toString();

    final latitude = location['latitude'] ?? location['lat'];
    final longitude = location['longitude'] ?? location['lng'];

    final imageUri =
        Uri.parse(
          '$baseUrl/v1/netradyne/v1/tenants/$tenant/event/preview/images',
        ).replace(
          queryParameters: {
            'startTime': '$timestamp',
            'endTime': '$endTime',
            'validityDuration': '3600',
            'vehicleNumber': vehicleNumber,
            'vin': vin,
            'licensePlateNumber': licensePlateNumber,
            if (latitude != null) 'latitude': '$latitude',
            if (longitude != null) 'longitude': '$longitude',
          },
        );

    final videoIds = videos
        .map((video) => (video as Map)['id'])
        .where((id) => id != null)
        .map((id) => id.toString())
        .join(',');

    final videoUri = Uri.parse(
      '$baseUrl/v1/netradyne/v1/tenants/$tenant/videoplayurl/${videoIds.isEmpty ? "1" : videoIds}',
    ).replace(queryParameters: {'validityDuration': '3600'});

    final imageResponse = await _authorizedGetUri(imageUri);
    final videoResponse = await _authorizedGetUri(videoUri);

    if (imageResponse.statusCode != 200) {
      throw Exception(
        'Failed to fetch preview images (${imageResponse.statusCode}): ${imageResponse.data}',
      );
    }

    if (videoResponse.statusCode != 200) {
      throw Exception(
        'Failed to fetch video URLs (${videoResponse.statusCode}): ${videoResponse.data}',
      );
    }

    final imageData =
        (imageResponse.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>? ??
        <String, dynamic>{};

    final videoData =
        (videoResponse.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>? ??
        <String, dynamic>{};

    final imageList = (imageData['images'] as List<dynamic>? ?? [])
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final item = entry.value as Map<String, dynamic>;

          return MediaItem(
            id: index + 1,
            type: 'image',
            title: (item['fileName'] ?? 'Image ${index + 1}').toString(),
            url: (item['imageUrl'] ?? '').toString(),
            thumbnailUrl: (item['imageUrl'] ?? '').toString(),
            mimeType: 'image/jpeg',
            source: 'netradyne-preview-images',
          );
        })
        .toList();

    final videoList = (videoData['urls'] as List<dynamic>? ?? [])
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final item = entry.value as Map<String, dynamic>;

          return MediaItem(
            id: _toInt(item['videoId']) ?? (index + 1),
            type: 'video',
            title: 'Video ${index + 1}',
            url: (item['url'] ?? '').toString(),
            thumbnailUrl: imageList.isNotEmpty
                ? imageList.first.thumbnailUrl
                : null,
            mimeType: 'video/mp4',
            source: 'netradyne-video-play-url',
          );
        })
        .toList();

    final event = EventItem(
      id: eventId,
      title: alertType.isEmpty ? 'Safety Event' : alertType,
      eventType: alertType,
      severity: severity,
      vehicleId: vehicleNumber,
      driverName: driverName,
      depot: [
        (location['city'] ?? '').toString(),
        (location['state'] ?? '').toString(),
      ].where((e) => e.trim().isNotEmpty).join(', '),
      status: (alertData['status'] ?? 'OPEN').toString(),
      timestamp: timestamp.toString(),
      location: [
        (location['address'] ?? '').toString(),
        (location['city'] ?? '').toString(),
        (location['state'] ?? '').toString(),
        (location['country'] ?? '').toString(),
      ].where((e) => e.trim().isNotEmpty).join(', '),
      thumbnailUrl: imageList.isNotEmpty ? imageList.first.thumbnailUrl : null,
      description: (details['subTypeDescription'] ?? alertType).toString(),
      netradyneAlertId: eventId,
    );

    return EventMediaResponse(
      event: event,
      images: imageList,
      videos: videoList,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }
}
