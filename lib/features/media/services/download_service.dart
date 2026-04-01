import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:media_store_plus/media_store_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/downloaded_media_model.dart';
import '../models/event_models.dart';
import '../../auth/services/auth_service.dart';

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
    await prefs.setString(
      _downloadsKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
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

  static Future<bool> _needsLegacyStoragePermission() async {
    if (!Platform.isAndroid) return false;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt <= 28;
  }

  static Future<void> _ensurePermissions(String mediaType) async {
    if (kIsWeb) return;

    if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      if (!status.isGranted && !status.isLimited) {
        throw Exception('Photo library permission denied');
      }
      return;
    }

    if (!Platform.isAndroid) return;

    if (await _needsLegacyStoragePermission()) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission denied');
      }
      return;
    }

    if (mediaType == 'image') {
      final status = await Permission.photos.request();
      if (!status.isGranted && !status.isLimited) {
        throw Exception('Photos permission denied');
      }
    } else if (mediaType == 'video') {
      final status = await Permission.videos.request();
      if (!status.isGranted && !status.isLimited) {
        throw Exception('Videos permission denied');
      }
    }
  }

  static Future<String> _writeTempFile(Uint8List bytes, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile.path;
  }

  static Future<String> _writePublicFile({
    required Uint8List bytes,
    required String fileName,
    required String mediaType,
  }) async {
    if (kIsWeb) {
      throw Exception('Downloads to device storage are not supported on web.');
    }

    if (Platform.isAndroid) {
      if (MediaStore.appFolder.isEmpty) {
        MediaStore.appFolder = 'NetraDyne FMS';
      }

      await MediaStore.ensureInitialized();

      final tempFilePath = await _writeTempFile(bytes, fileName);

      final SaveInfo? saved = await MediaStore().saveFile(
        tempFilePath: tempFilePath,
        dirType: DirType.download,
        dirName: DirName.download,
      );

      try {
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      if (saved == null) {
        throw Exception('Failed to save file to Downloads folder');
      }

      final savedUri = saved.uri?.toString() ?? '';
      final savedName = saved.name ?? '';

      if (savedUri.isEmpty && savedName.isEmpty) {
        throw Exception('Failed to save file to Downloads folder');
      }

      return savedUri.isNotEmpty ? savedUri : savedName;
    }

    if (Platform.isIOS) {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<DownloadedMediaItem> downloadMedia({
    required int eventId,
    required MediaItem media,
  }) async {
    await _ensurePermissions(media.type);

    final response = await http.get(Uri.parse(media.url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download media (${response.statusCode})');
    }

    final bytes = response.bodyBytes;
    final ext = _extensionFromUrl(media.url, media.type);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeTitle = _sanitizeFileName(
      media.title.isEmpty ? 'media' : media.title,
    );
    final fileName = '${media.type}_${eventId}_${safeTitle}_$timestamp.$ext';

    final publicPath = await _writePublicFile(
      bytes: bytes,
      fileName: fileName,
      mediaType: media.type,
    );

    final item = DownloadedMediaItem(
      id: '${eventId}_${media.id}_$timestamp',
      eventId: eventId,
      title: media.title,
      type: media.type,
      remoteUrl: media.url,
      localPath: publicPath,
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
    if (!item.localPath.startsWith('content://')) {
      final file = File(item.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    final existing = await getDownloads();
    existing.removeWhere((e) => e.id == item.id);
    await _saveDownloads(existing);
  }

  static Future<void> openDownload(DownloadedMediaItem item) async {
    String pathToOpen = item.localPath;

    // content:// URIs (Android MediaStore) cannot be opened directly by
    // open_filex — it needs a real filesystem path. Re-fetch the file from
    // the remote URL into the temp directory and open from there instead.
    if (item.localPath.startsWith('content://')) {
      final ext = _extensionFromUrl(item.remoteUrl, item.type);
      final safeTitle = _sanitizeFileName(
        item.title.isEmpty ? 'media' : item.title,
      );
      final tempFileName = '${item.type}_${item.eventId}_${safeTitle}_open.$ext';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$tempFileName');

      // Re-use cached temp file if it already exists from a previous open
      if (!await tempFile.exists()) {
        final response = await http.get(Uri.parse(item.remoteUrl));
        if (response.statusCode != 200) {
          throw Exception(
              'Could not fetch media for opening (${response.statusCode})');
        }
        await tempFile.writeAsBytes(response.bodyBytes, flush: true);
      }

      pathToOpen = tempFile.path;
    }

    final mimeType = item.type == 'video' ? 'video/*' : 'image/*';
    final result = await OpenFilex.open(pathToOpen, type: mimeType);
    if (result.type.name != 'done') {
      if (kDebugMode) debugPrint('Open file result: ${result.message}');
      throw Exception('Could not open file: ${result.message}');
    }
  }
}