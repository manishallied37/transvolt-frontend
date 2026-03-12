import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/downloaded_media_model.dart';
import '../models/event_models.dart';

class DownloadService {
  static const String _downloadsKey = 'downloaded_media_items';

  static Future<List<DownloadedMediaItem>> getDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_downloadsKey);

    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(raw);
    return decoded
        .map((e) => DownloadedMediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _saveDownloads(List<DownloadedMediaItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_downloadsKey, raw);
  }

  static String _sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[^\w\s.-]'), '').replaceAll(' ', '_');
  }

  static String _extensionFromUrl(String url, String fallbackType) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? '';

    if (path.contains('.')) {
      final ext = path.split('.').last.toLowerCase();
      if (ext.length <= 5) return ext;
    }

    return fallbackType == 'video' ? 'mp4' : 'jpg';
  }

  static Future<Directory> _getDownloadDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  static Future<DownloadedMediaItem> downloadMedia({
    required int eventId,
    required MediaItem media,
  }) async {
    final response = await http.get(Uri.parse(media.url));

    if (response.statusCode != 200) {
      throw Exception('Failed to download media (${response.statusCode})');
    }

    final Uint8List bytes = response.bodyBytes;
    final downloadDir = await _getDownloadDirectory();

    final ext = _extensionFromUrl(media.url, media.type);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeTitle = _sanitizeFileName(
      media.title.isEmpty ? 'media' : media.title,
    );
    final fileName = '${media.type}_${eventId}_${safeTitle}_$timestamp.$ext';

    final file = File('${downloadDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    final item = DownloadedMediaItem(
      id: '${eventId}_${media.id}_$timestamp',
      eventId: eventId,
      title: media.title,
      type: media.type,
      remoteUrl: media.url,
      localPath: file.path,
      downloadedAt: DateTime.now(),
    );

    final existing = await getDownloads();

    final alreadyExists = existing.any(
      (e) => e.remoteUrl == item.remoteUrl && e.eventId == item.eventId,
    );

    if (!alreadyExists) {
      existing.insert(0, item);
      await _saveDownloads(existing);
    }

    return item;
  }

  static Future<void> deleteDownload(DownloadedMediaItem item) async {
    final file = File(item.localPath);
    if (await file.exists()) {
      await file.delete();
    }

    final existing = await getDownloads();
    existing.removeWhere((e) => e.id == item.id);
    await _saveDownloads(existing);
  }

  static Future<void> openDownload(DownloadedMediaItem item) async {
    final file = File(item.localPath);
    if (!await file.exists()) {
      throw Exception('Downloaded file not found');
    }

    final result = await OpenFilex.open(item.localPath);
    if (result.type.name != 'done') {
      if (kDebugMode) {
        print('Open file result: ${result.message}');
      }
    }
  }
}
