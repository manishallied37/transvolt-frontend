import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MediaApiService {
  static String baseUrl = dotenv.env['API_URL']!;

  static Future<List<MediaImage>> fetchImages(String vehicleNumber) async {
    final res = await http.get(
      Uri.parse("$baseUrl/api/events/images/$vehicleNumber"),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load images");
    }

    final data = jsonDecode(res.body);

    return (data as List).map((e) => MediaImage.fromJson(e)).toList();
  }

  static Future<MediaVideo> requestVideo(String eventId) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/events/video-request"),
      body: jsonEncode({"eventId": eventId}),
      headers: {"Content-Type": "application/json"},
    );

    final data = jsonDecode(res.body);

    return MediaVideo.fromJson(data);
  }

  static Future<MediaVideo> pollVideo(String requestId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/api/events/video-status/$requestId"),
    );

    final data = jsonDecode(res.body);

    return MediaVideo.fromJson(data);
  }
}
