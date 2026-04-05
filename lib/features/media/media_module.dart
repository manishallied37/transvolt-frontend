import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/api_service.dart';
import 'models/event_models.dart';
import 'services/download_service.dart';
import 'widgets/video_player_card.dart';
import 'screens/downloads_screen.dart';
import '../stream/screens/stream_screen.dart';

class MediaModule extends StatefulWidget {
  final int eventId;
  final Map<String, dynamic> alertData;

  const MediaModule({
    super.key,
    required this.eventId,
    required this.alertData,
  });

  @override
  State<MediaModule> createState() => _MediaModuleState();
}

class _MediaModuleState extends State<MediaModule>
    with SingleTickerProviderStateMixin {
  late Future<EventMediaResponse> _eventMediaFuture;
  final Set<int> _downloadingIds = <int>{};
  Set<String> _downloadedUrls = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _eventMediaFuture = ApiService.getEventMedia(
      widget.eventId,
      widget.alertData,
    );

    _tabController = TabController(length: 2, vsync: this);
    _loadDownloadedUrls();
  }

  Future<void> _loadDownloadedUrls() async {
    final urls = await DownloadService.getDownloadedUrls(
      eventId: widget.eventId,
    );
    if (mounted) {
      setState(() {
        _downloadedUrls = urls;
      });
    }
  }

  Future<void> _reload() async {
    setState(() {
      _eventMediaFuture = ApiService.getEventMedia(
        widget.eventId,
        widget.alertData,
      );
    });
    await _eventMediaFuture;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _downloadMedia(MediaItem media) async {
    setState(() {
      _downloadingIds.add(media.id);
    });

    try {
      await DownloadService.downloadMedia(
        eventId: widget.eventId,
        media: media,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${media.title} downloaded successfully')),
      );
      // Refresh the set of already-downloaded URLs so the icon updates.
      await _loadDownloadedUrls();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(media.id);
        });
      }
    }
  }

  void _openImageViewer(List<MediaItem> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageGalleryViewerScreen(
          images: images,
          initialIndex: initialIndex,
          onDownload: _downloadMedia,
          downloadingIds: _downloadingIds,
          downloadedUrls: _downloadedUrls,
        ),
      ),
    );
  }

  void _openLivestream(EventItem event) {
    final vehicle =
        (widget.alertData['vehicle'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final camera =
        (widget.alertData['camera'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final driver =
        (widget.alertData['driver'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final details =
        (widget.alertData['details'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final location =
        (details['location'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final vehicleNumber = _firstNonEmptyText([vehicle['vehicleNumber']]);
    final vin = _firstNonEmptyText([vehicle['vin']]);
    final licensePlateNumber = _firstNonEmptyText([
      vehicle['licensePlateNumber'],
    ]);
    final cameraId = _firstNonEmptyText([camera['id']]);

    // ── NEW: extract driver + event context ──
    final driverName = [driver['firstName'], driver['lastName']]
        .where((v) => (v ?? '').toString().trim().isNotEmpty)
        .map((v) => v.toString().trim())
        .join(' ');

    final latestEventType = _firstNonEmptyText([details['typeDescription']]);
    final latestSeverity = _firstNonEmptyText([details['severityDescription']]);
    final latestLocation =
        [location['address'], location['city'], location['state']]
            .where((v) => (v ?? '').toString().trim().isNotEmpty)
            .map((v) => v.toString().trim())
            .join(', ');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StreamScreen(
          launchArgs: StreamScreenLaunchArgs(
            vehicleNumber: vehicleNumber.isEmpty ? null : vehicleNumber,
            vin: vin.isEmpty ? null : vin,
            licensePlateNumber: licensePlateNumber.isEmpty
                ? null
                : licensePlateNumber,
            cameraId: cameraId.isEmpty ? null : cameraId,
            // ── NEW fields ──
            driverName: driverName.isEmpty ? null : driverName,
            latestEventType: latestEventType.isEmpty ? null : latestEventType,
            latestSeverity: latestSeverity.isEmpty ? null : latestSeverity,
            latestLocation: latestLocation.isEmpty ? null : latestLocation,
            autoPlay: true,
            prefillSearch: true,
          ),
        ),
      ),
    );
  }

  String _firstNonEmptyText(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _resolveMediaUrl(String? rawUrl) {
    final input = (rawUrl ?? '').trim();
    if (input.isEmpty) return '';

    Uri? uri;
    try {
      uri = Uri.parse(input);
    } catch (_) {
      return input;
    }

    if (!uri.hasScheme) return input;

    if (!kIsWeb &&
        Platform.isAndroid &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      return uri.replace(host: '10.0.2.2').toString();
    }

    return input;
  }

  String _formatHeading(String value) {
    final normalized = value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) return 'Safety Event';

    return normalized
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1).toLowerCase() : ''}',
        )
        .join(' ');
  }

  String _formatTimestamp(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return '—';

    final millis = int.tryParse(trimmed);
    DateTime? parsed;

    if (millis != null) {
      parsed = DateTime.fromMillisecondsSinceEpoch(millis);
    } else {
      parsed = DateTime.tryParse(trimmed);
    }

    if (parsed == null) return trimmed;

    return DateFormat('dd MMM yyyy • hh:mm a').format(parsed.toLocal());
  }

  Widget _buildHeader(EventItem event) {
    final title = _formatHeading(event.title);
    final formattedTime = _formatTimestamp(event.timestamp);

    final metaItems = <String>[
      if (event.vehicleId.trim().isNotEmpty) event.vehicleId.trim(),
      if (event.severity.trim().isNotEmpty) event.severity.trim(),
      if (event.status.trim().isNotEmpty) event.status.trim(),
    ];

    final secondaryParts = <String>[
      if (event.driverName.trim().isNotEmpty) event.driverName.trim(),
      if (event.depot.trim().isNotEmpty) event.depot.trim(),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF17212B),
            ),
          ),
          if (metaItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metaItems
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD8DEE9)),
                      ),
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF42526E),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (secondaryParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              secondaryParts.join(' • '),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            formattedTime,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8A94A6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImages(List<MediaItem> images) {
    if (images.isEmpty) {
      return const _EmptyState(
        icon: Icons.photo_library_outlined,
        title: 'No images available',
        subtitle: 'No preview images were returned for this event.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 2;

        if (width >= 1100) {
          crossAxisCount = 4;
        } else if (width >= 700) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: images.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, index) {
            final media = images[index];
            final isDownloading = _downloadingIds.contains(media.id);
            final isDownloaded = _downloadedUrls.contains(media.url);
            final previewUrl = _resolveMediaUrl(
              media.thumbnailUrl ?? media.url,
            );

            return Card(
              elevation: 1,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: previewUrl.isEmpty
                    ? null
                    : () => _openImageViewer(images, index),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          previewUrl.isEmpty
                              ? Container(
                                  color: Colors.grey.shade300,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    size: 42,
                                  ),
                                )
                              : Hero(
                                  tag: 'media-image-${media.id}',
                                  child: Image.network(
                                    previewUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade300,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          size: 42,
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        color: Colors.grey.shade200,
                                        alignment: Alignment.center,
                                        child:
                                            const CircularProgressIndicator(),
                                      );
                                    },
                                  ),
                                ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Material(
                              color: isDownloaded
                                  ? const Color(0xFF534AB7).withOpacity(0.85)
                                  : Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: (isDownloading || isDownloaded)
                                    ? null
                                    : () => _downloadMedia(media),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: isDownloading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          isDownloaded
                                              ? Icons.check_circle
                                              : Icons.download,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Text(
                        media.title.trim().isEmpty ? 'Image' : media.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF17212B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  MediaItem _copyVideoWithResolvedUrl(MediaItem video) {
    return video.copyWith(
      url: _resolveMediaUrl(video.url),
      thumbnailUrl: video.thumbnailUrl == null
          ? null
          : _resolveMediaUrl(video.thumbnailUrl),
    );
  }

  Widget _buildVideos(EventItem event, List<MediaItem> videos) {
    if (videos.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLivestreamLaunchCard(event),
          const SizedBox(height: 16),
          const _EmptyState(
            icon: Icons.videocam_off_outlined,
            title: 'No videos available',
            subtitle: 'No video clips were returned for this event.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLivestreamLaunchCard(event),
        const SizedBox(height: 16),
        ...videos.map(
          (video) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: VideoPlayerCard(
              media: _copyVideoWithResolvedUrl(video),
              onDownload: () => _downloadMedia(video),
              isDownloading: _downloadingIds.contains(video.id),
              isDownloaded: _downloadedUrls.contains(video.url),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLivestreamLaunchCard(EventItem event) {
    final vehicle =
        (widget.alertData['vehicle'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final camera =
        (widget.alertData['camera'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final vehicleNumber = _firstNonEmptyText([
      vehicle['vehicleNumber'],
      event.vehicleId,
    ]);
    final cameraId = _firstNonEmptyText([camera['id']]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.live_tv_outlined, color: Color(0xFF17212B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Watch livestream for this event',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17212B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            vehicleNumber.isEmpty
                ? 'Open the livestream screen and start playback for the related vehicle.'
                : 'Vehicle: $vehicleNumber${cameraId.isNotEmpty ? ' • Camera: $cameraId' : ''}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF5B6472),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openLivestream(event),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Livestream'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFF5B4FCF), width: 2),
                foregroundColor: const Color(0xFF5B4FCF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent({
    required String storageKey,
    required EventItem event,
    required Widget content,
  }) {
    return _MediaTabContent(
      key: PageStorageKey(storageKey),
      event: event,
      storageKey: storageKey,
      content: content,
      onRefresh: _reload,
      headerBuilder: _buildHeader,
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 54),
              const SizedBox(height: 12),
              const Text(
                'Failed to load media',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Media'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Images'),
            Tab(text: 'Videos'),
          ],
        ),
      ),
      body: FutureBuilder<EventMediaResponse>(
        future: _eventMediaFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error!);
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No event data found.'));
          }

          final data = snapshot.data!;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTabContent(
                storageKey: 'event-media-images',
                event: data.event,
                content: _buildImages(data.images),
              ),
              _buildTabContent(
                storageKey: 'event-media-videos',
                event: data.event,
                content: _buildVideos(data.event, data.videos),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MediaTabContent extends StatefulWidget {
  final EventItem event;
  final String storageKey;
  final Widget content;
  final Future<void> Function() onRefresh;
  final Widget Function(EventItem event) headerBuilder;

  const _MediaTabContent({
    super.key,
    required this.event,
    required this.storageKey,
    required this.content,
    required this.onRefresh,
    required this.headerBuilder,
  });

  @override
  State<_MediaTabContent> createState() => _MediaTabContentState();
}

class _MediaTabContentState extends State<_MediaTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        key: PageStorageKey(widget.storageKey),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.headerBuilder(widget.event),
            const SizedBox(height: 12),
            widget.content,
          ],
        ),
      ),
    );
  }
}

class _ImageGalleryViewerScreen extends StatefulWidget {
  final List<MediaItem> images;
  final int initialIndex;
  final Future<void> Function(MediaItem media) onDownload;
  final Set<int> downloadingIds;
  final Set<String> downloadedUrls;

  const _ImageGalleryViewerScreen({
    required this.images,
    required this.initialIndex,
    required this.onDownload,
    required this.downloadingIds,
    required this.downloadedUrls,
  });

  @override
  State<_ImageGalleryViewerScreen> createState() =>
      _ImageGalleryViewerScreenState();
}

class _ImageGalleryViewerScreenState extends State<_ImageGalleryViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  String _resolveMediaUrl(String? rawUrl) {
    final input = (rawUrl ?? '').trim();
    if (input.isEmpty) return '';

    Uri? uri;
    try {
      uri = Uri.parse(input);
    } catch (_) {
      return input;
    }

    if (!uri.hasScheme) return input;

    if (!kIsWeb &&
        Platform.isAndroid &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      return uri.replace(host: '10.0.2.2').toString();
    }

    return input;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMedia = widget.images[_currentIndex];
    final isDownloading = widget.downloadingIds.contains(currentMedia.id);
    final isDownloaded = widget.downloadedUrls.contains(currentMedia.url);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.images.length}'),
        actions: [
          IconButton(
            icon: isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isDownloaded ? Icons.check_circle : Icons.download,
                    color: isDownloaded ? Colors.greenAccent : Colors.white,
                  ),
            onPressed: (isDownloading || isDownloaded)
                ? null
                : () async {
                    await widget.onDownload(currentMedia);
                    if (mounted) setState(() {});
                  },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final media = widget.images[index];
          final imageUrl = _resolveMediaUrl(media.url);

          return Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Hero(
                tag: 'media-image-${media.id}',
                child: imageUrl.isEmpty
                    ? const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 64,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white,
                            size: 64,
                          );
                        },
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: Colors.grey.shade600),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
