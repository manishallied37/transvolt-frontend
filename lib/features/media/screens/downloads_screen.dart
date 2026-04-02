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
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _downloadsFuture = DownloadService.getDownloads();
  }

  Future<void> _refresh() async {
    setState(() {
      _downloadsFuture = DownloadService.getDownloads();
      _selectedIndices.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteItem(DownloadedMediaItem item) async {
    await DownloadService.deleteDownload(item);
    await _refresh();
  }

  Future<void> _deleteSelected(List<DownloadedMediaItem> items) async {
    final selectedItems = _selectedIndices.map((i) => items[i]).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected'),
        content: Text(
          'Delete ${selectedItems.length} item${selectedItems.length == 1 ? '' : 's'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final item in selectedItems) {
      await DownloadService.deleteDownload(item);
    }
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

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIndices.clear();
    });
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll(int totalCount) {
    setState(() {
      if (_selectedIndices.length == totalCount) {
        _selectedIndices.clear();
      } else {
        _selectedIndices
          ..clear()
          ..addAll(List.generate(totalCount, (i) => i));
      }
    });
  }

  Widget _buildThumbnail(DownloadedMediaItem item) {
    if (item.type == 'image' && !item.localPath.startsWith('content://')) {
      final file = File(item.localPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, width: 56, height: 56, fit: BoxFit.cover),
        );
      }
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
    return FutureBuilder<List<DownloadedMediaItem>>(
      future: _downloadsFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final allSelected =
            items.isNotEmpty && _selectedIndices.length == items.length;

        return Scaffold(
          appBar: AppBar(
            title: _isSelectionMode
                ? Text('${_selectedIndices.length} selected')
                : const Text('Downloads'),
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSelectionMode,
                    tooltip: 'Cancel',
                  )
                : null,
            actions: [
              if (!_isSelectionMode && items.isNotEmpty)
                TextButton.icon(
                  onPressed: _toggleSelectionMode,
                  icon: const Icon(Icons.check_box_outlined, size: 20),
                  label: const Text('Select'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              if (_isSelectionMode && items.isNotEmpty) ...[
                TextButton(
                  onPressed: () => _selectAll(items.length),
                  child: Text(allSelected ? 'Deselect All' : 'Select All'),
                ),
                if (_selectedIndices.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Delete selected',
                    onPressed: () => _deleteSelected(items),
                  ),
              ],
            ],
          ),
          body: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }

              if (items.isEmpty) {
                return const Center(child: Text('No downloads yet.'));
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _selectedIndices.contains(index);

                    return Card(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                                .withValues(alpha: 0.4)
                          : null,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelect(index),
                              )
                            : GestureDetector(
                                onLongPress: () {
                                  setState(() {
                                    _isSelectionMode = true;
                                    _selectedIndices.add(index);
                                  });
                                },
                                child: _buildThumbnail(item),
                              ),
                        title: Text(
                          item.title.isEmpty ? 'Untitled media' : item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Type: ${item.type}\nEvent ID: ${item.eventId}',
                        ),
                        isThreeLine: true,
                        onTap: _isSelectionMode
                            ? () => _toggleSelect(index)
                            : () => _openItem(item),
                        onLongPress: _isSelectionMode
                            ? null
                            : () {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedIndices.add(index);
                                });
                              },
                        trailing: _isSelectionMode
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete',
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Item'),
                                      content: Text(
                                        'Delete "${item.title.isEmpty ? 'this media' : item.title}"?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await _deleteItem(item);
                                  }
                                },
                              ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
