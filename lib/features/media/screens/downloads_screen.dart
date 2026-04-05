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
  List<DownloadedMediaItem> _items = [];
  // Maps item.id → whether the file exists on device right now.
  Map<String, bool> _existenceMap = {};
  bool _loading = true;
  String? _error;

  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await DownloadService.getDownloads();

      // Check every file's existence concurrently using plain File.exists().
      // At save time (download_service.dart) we now resolve content:// URIs
      // to real filesystem paths, so this always works.
      final entries = await Future.wait(
        items.map((item) async {
          final exists = await _checkExists(item.localPath);
          return MapEntry(item.id, exists);
        }),
      );

      if (!mounted) return;
      setState(() {
        _items = items;
        _existenceMap = Map.fromEntries(entries);
        _loading = false;
        _selectedIndices.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static Future<bool> _checkExists(String path) async {
    if (path.isEmpty) return false;
    // content:// URIs that were NOT resolved (edge-case fallback) are assumed
    // present – we can't stat them without platform channel overhead.
    if (path.startsWith('content://')) return true;
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> _refresh() async => _load();

  // ---------------------------------------------------------------------------
  // Delete / remove helpers
  // ---------------------------------------------------------------------------

  Future<({bool confirmed, bool deleteFromDevice})?> _confirmSingleDelete(
    DownloadedMediaItem item,
  ) async {
    bool deleteFromDevice = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Delete Download'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remove "${item.title.isEmpty ? 'this media' : item.title}" from your downloads list?',
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: deleteFromDevice,
                contentPadding: EdgeInsets.zero,
                title: const Text('Delete from device as well'),
                onChanged: (val) =>
                    setDialogState(() => deleteFromDevice = val ?? true),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return null;
    return (confirmed: true, deleteFromDevice: deleteFromDevice);
  }

  Future<void> _deleteItem(DownloadedMediaItem item) async {
    final decision = await _confirmSingleDelete(item);
    if (decision == null) return;
    await DownloadService.deleteDownload(
      item,
      deleteFromDevice: decision.deleteFromDevice,
    );
    await _refresh();
  }

  Future<({bool confirmed, bool deleteFromDevice})?> _confirmBulkDelete(
    int count,
  ) async {
    bool deleteFromDevice = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Delete Selected'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remove $count item${count == 1 ? '' : 's'} from your downloads list?',
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: deleteFromDevice,
                contentPadding: EdgeInsets.zero,
                title: const Text('Delete from device as well'),
                onChanged: (val) =>
                    setDialogState(() => deleteFromDevice = val ?? true),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return null;
    return (confirmed: true, deleteFromDevice: deleteFromDevice);
  }

  Future<void> _deleteSelected() async {
    final selectedItems = _selectedIndices.map((i) => _items[i]).toList();
    final decision = await _confirmBulkDelete(selectedItems.length);
    if (decision == null) return;
    for (final item in selectedItems) {
      await DownloadService.deleteDownload(
        item,
        deleteFromDevice: decision.deleteFromDevice,
      );
    }
    await _refresh();
  }

  Future<void> _removeMissingRecord(DownloadedMediaItem item) async {
    await DownloadService.removeRecord(item);
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

  // ---------------------------------------------------------------------------
  // Selection helpers
  // ---------------------------------------------------------------------------

  void _toggleSelectionMode() => setState(() {
    _isSelectionMode = !_isSelectionMode;
    _selectedIndices.clear();
  });

  void _toggleSelect(int index) => setState(() {
    if (_selectedIndices.contains(index)) {
      _selectedIndices.remove(index);
    } else {
      _selectedIndices.add(index);
    }
  });

  void _selectAll() => setState(() {
    if (_selectedIndices.length == _items.length) {
      _selectedIndices.clear();
    } else {
      _selectedIndices
        ..clear()
        ..addAll(List.generate(_items.length, (i) => i));
    }
  });

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _buildThumbnail(DownloadedMediaItem item, {required bool missing}) {
    if (!missing &&
        item.type == 'image' &&
        !item.localPath.startsWith('content://')) {
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
        color: missing ? Colors.grey.shade300 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        missing
            ? Icons.broken_image_outlined
            : (item.type == 'video' ? Icons.videocam : Icons.image),
        size: 28,
        color: missing ? Colors.grey.shade500 : null,
      ),
    );
  }

  Widget _buildTile(int index) {
    final item = _items[index];
    final bool fileExists = _existenceMap[item.id] ?? true;
    final bool isMissing = !fileExists;
    final bool isSelected = _selectedIndices.contains(index);

    final titleStyle = TextStyle(
      color: isMissing ? Colors.grey : null,
      decoration: isMissing ? TextDecoration.lineThrough : null,
      decorationColor: Colors.grey,
    );

    Widget leading;
    if (_isSelectionMode) {
      leading = Checkbox(
        value: isSelected,
        onChanged: (_) => _toggleSelect(index),
      );
    } else {
      leading = GestureDetector(
        onLongPress: isMissing
            ? null
            : () => setState(() {
                _isSelectionMode = true;
                _selectedIndices.add(index);
              }),
        child: _buildThumbnail(item, missing: isMissing),
      );
    }

    Widget? trailing;
    if (!_isSelectionMode) {
      if (isMissing) {
        trailing = IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          tooltip: 'Remove from list',
          onPressed: () => _removeMissingRecord(item),
        );
      } else {
        trailing = IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Delete',
          onPressed: () => _deleteItem(item),
        );
      }
    }

    return Opacity(
      opacity: isMissing ? 0.55 : 1.0,
      child: Card(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
            : null,
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: leading,
          title: Text(
            item.title.isEmpty ? 'Untitled media' : item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Type: ${item.type}  •  Event ID: ${item.eventId}',
                style: TextStyle(
                  color: isMissing ? Colors.grey.shade400 : null,
                ),
              ),
              if (isMissing)
                const Text(
                  'File not found on device',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          isThreeLine: isMissing,
          onTap: _isSelectionMode
              ? () => _toggleSelect(index)
              : isMissing
              ? null
              : () => _openItem(item),
          onLongPress: _isSelectionMode || isMissing
              ? null
              : () => setState(() {
                  _isSelectionMode = true;
                  _selectedIndices.add(index);
                }),
          trailing: trailing,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _items.isNotEmpty && _selectedIndices.length == _items.length;

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
          if (!_isSelectionMode && _items.isNotEmpty)
            TextButton.icon(
              onPressed: _toggleSelectionMode,
              icon: const Icon(Icons.check_box_outlined, size: 20),
              label: const Text('Select'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          if (_isSelectionMode && _items.isNotEmpty) ...[
            TextButton(
              onPressed: _selectAll,
              child: Text(allSelected ? 'Deselect All' : 'Select All'),
            ),
            if (_selectedIndices.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete selected',
                onPressed: _deleteSelected,
              ),
          ],
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(child: Text(_error!));
          }

          if (_items.isEmpty) {
            return const Center(child: Text('No downloads yet.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _buildTile(index),
            ),
          );
        },
      ),
    );
  }
}
