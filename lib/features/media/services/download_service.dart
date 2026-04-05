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

class DownloadService {
  static const String _downloadsKey = 'downloaded_media_items';

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  static String _sanitizeFileName(String input) =>
      input.replaceAll(RegExp(r'[^\w\s.-]'), '').replaceAll(' ', '_');

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
      if (!status.isGranted) throw Exception('Storage permission denied');
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

  // ---------------------------------------------------------------------------
  // Write exclusively to external / public storage
  // ---------------------------------------------------------------------------

  /// Saves [bytes] to the device's public Downloads folder and returns the
  /// canonical external path. On Android ≥ Q this is a content:// URI; on
  /// older Android and iOS it is a real file-system path.
  ///
  /// No copy is kept in app-internal storage.
  static Future<String> _writeExternalFile({
    required Uint8List bytes,
    required String fileName,
    required String mediaType,
  }) async {
    if (kIsWeb) {
      throw Exception('Device downloads are not supported on web.');
    }

    if (Platform.isAndroid) {
      if (MediaStore.appFolder.isEmpty) {
        MediaStore.appFolder = 'NetraDyne FMS';
      }
      await MediaStore.ensureInitialized();

      // Write to a temp file first – MediaStore needs a real FS path.
      final tempFilePath = await _writeTempFile(bytes, fileName);

      final SaveInfo? saved = await MediaStore().saveFile(
        tempFilePath: tempFilePath,
        dirType: DirType.download,
        dirName: DirName.download,
      );

      // Always clean up the temp file – we only keep the external copy.
      try {
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}

      if (saved == null) {
        throw Exception('Failed to save file to Downloads folder');
      }

      final savedUri = saved.uri?.toString() ?? '';
      final savedName = saved.name ?? '';

      if (savedUri.isEmpty && savedName.isEmpty) {
        throw Exception('Failed to save file to Downloads folder');
      }

      // Immediately resolve the content:// URI to a real filesystem path so
      // that File.exists() works reliably for missing-file detection later.
      // getFilePathFromUri returns null if resolution fails; fall back to
      // the URI string so the record is still persisted.
      if (savedUri.isNotEmpty) {
        try {
          final resolvedPath = await MediaStore().getFilePathFromUri(
            uriString: savedUri,
          );
          if (resolvedPath != null && resolvedPath.isNotEmpty) {
            return resolvedPath;
          }
        } catch (_) {}
        return savedUri; // fallback: keep URI if resolution failed
      }

      return savedName;
    }

    if (Platform.isIOS) {
      // On iOS use the shared Documents directory so the file is visible in
      // the Files app (external to the app sandbox from the user's POV).
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File('${docsDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }

    // Desktop fallback – write to user's Downloads directory when available.
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final file = File('${downloadsDir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      }
    } catch (_) {}

    final docsDir = await getApplicationDocumentsDirectory();
    final file = File('${docsDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Downloads [media] and stores it **only** in external/public storage.
  /// The returned [DownloadedMediaItem] records the external path so the
  /// app always references the single authoritative copy.
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

    // Write to external storage only – no internal copy.
    final externalPath = await _writeExternalFile(
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
      localPath: externalPath,
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

  /// Returns true if the given [remoteUrl] has already been downloaded for
  /// the given [eventId].
  static Future<bool> isAlreadyDownloaded({
    required int eventId,
    required String remoteUrl,
  }) async {
    final existing = await getDownloads();
    return existing.any(
      (e) => e.remoteUrl == remoteUrl && e.eventId == eventId,
    );
  }

  /// Returns the set of remoteUrls that have already been downloaded for
  /// the given [eventId].
  static Future<Set<String>> getDownloadedUrls({required int eventId}) async {
    final existing = await getDownloads();
    return existing
        .where((e) => e.eventId == eventId)
        .map((e) => e.remoteUrl)
        .toSet();
  }

  /// Removes the download record from the app list.
  ///
  /// [deleteFromDevice] controls whether the actual file is also deleted
  /// from external storage. Pass `false` to keep the file but remove the
  /// entry from the downloads screen.
  static Future<void> deleteDownload(
    DownloadedMediaItem item, {
    bool deleteFromDevice = true,
  }) async {
    if (deleteFromDevice) {
      await _deletePhysicalFile(item);
    }

    final existing = await getDownloads();
    existing.removeWhere((e) => e.id == item.id);
    await _saveDownloads(existing);
  }

  /// Deletes only the record from the downloads list without touching storage.
  /// Used when the file has already been removed externally.
  static Future<void> removeRecord(DownloadedMediaItem item) async {
    final existing = await getDownloads();
    existing.removeWhere((e) => e.id == item.id);
    await _saveDownloads(existing);
  }

  /// Attempts to delete the physical file from device storage.
  static Future<void> _deletePhysicalFile(DownloadedMediaItem item) async {
    if (item.localPath.startsWith('content://')) {
      // content:// URI from MediaStore – use deleteFileUsingUri which accepts
      // the URI string directly (no fileName parameter needed).
      try {
        await MediaStore().deleteFileUsingUri(uriString: item.localPath);
      } catch (e) {
        if (kDebugMode) debugPrint('MediaStore deleteFileUsingUri failed: $e');
      }
      return;
    }

    // Regular filesystem path (iOS, legacy Android, desktop).
    try {
      final file = File(item.localPath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('File delete failed: $e');
    }
  }

  /// Opens the media file with the device's default app.
  ///
  /// For content:// URIs the file is re-fetched into the temp directory
  /// because [OpenFilex] requires a real filesystem path.
  static Future<void> openDownload(DownloadedMediaItem item) async {
    String pathToOpen = item.localPath;

    if (item.localPath.startsWith('content://')) {
      final ext = _extensionFromUrl(item.remoteUrl, item.type);
      final safeTitle = _sanitizeFileName(
        item.title.isEmpty ? 'media' : item.title,
      );
      final tempFileName =
          '${item.type}_${item.eventId}_${safeTitle}_open.$ext';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$tempFileName');

      // Re-use cached temp file from a previous open.
      if (!await tempFile.exists()) {
        final response = await http.get(Uri.parse(item.remoteUrl));
        if (response.statusCode != 200) {
          throw Exception(
            'Could not fetch media for opening (${response.statusCode})',
          );
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
