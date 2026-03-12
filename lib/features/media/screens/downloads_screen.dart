import 'dart:io';

import 'package:flutter/material.dart';

import '../models/downloaded_media_model.dart';
import '../services/download_service.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late Future<List<DownloadedMediaItem>> _downloadsFuture;

  @override
  void initState() {
    super.initState();
    _downloadsFuture = DownloadService.getDownloads();
  }

  Future<void> _refresh() async {
    setState(() {
      _downloadsFuture = DownloadService.getDownloads();
    });
  }

  Future<void> _deleteItem(DownloadedMediaItem item) async {
    await DownloadService.deleteDownload(item);
    await _refresh();
  }

  Future<void> _openItem(DownloadedMediaItem item) async {
    try {
      await DownloadService.openDownload(item);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildThumbnail(DownloadedMediaItem item) {
    if (item.type == 'image' && File(item.localPath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(item.localPath),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        item.type == 'video' ? Icons.videocam : Icons.image,
        size: 28,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: FutureBuilder<List<DownloadedMediaItem>>(
        future: _downloadsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(child: Text('No downloads yet.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: _buildThumbnail(item),
                    title: Text(
                      item.title.isEmpty ? 'Untitled media' : item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Type: ${item.type}\nEvent ID: ${item.eventId}',
                    ),
                    isThreeLine: true,
                    onTap: () => _openItem(item),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'open') {
                          await _openItem(item);
                        } else if (value == 'delete') {
                          await _deleteItem(item);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'open', child: Text('Open')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
