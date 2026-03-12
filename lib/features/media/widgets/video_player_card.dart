import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/event_models.dart';

class VideoPlayerCard extends StatefulWidget {
  final MediaItem media;
  final VoidCallback? onDownload;
  final bool isDownloading;

  const VideoPlayerCard({
    super.key,
    required this.media,
    this.onDownload,
    this.isDownloading = false,
  });

  @override
  State<VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<VideoPlayerCard> {
  static _VideoPlayerCardState? _activeInlinePlayer;

  VideoPlayerController? _controller;
  VoidCallback? _controllerListener;

  bool _isInitializing = false;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;

  Timer? _hideControlsTimer;
  Timer? _disposeIdleTimer;

  final List<double> _speedOptions = [0.5, 1.0, 1.25, 1.5, 2.0];
  final List<double> _volumeOptions = [0.0, 0.25, 0.5, 0.75, 1.0];

  @override
  void dispose() {
    if (identical(_activeInlinePlayer, this)) {
      _activeInlinePlayer = null;
    }
    _hideControlsTimer?.cancel();
    _disposeIdleTimer?.cancel();
    _disposeController();
    super.dispose();
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized || _isInitializing) return;

    _disposeIdleTimer?.cancel();
    _releaseOtherActiveInlinePlayer();

    setState(() {
      _isInitializing = true;
      _hasError = false;
      _showControls = true;
    });

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.media.url),
      );

      await controller.initialize();
      await controller.setLooping(false);
      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.setVolume(_volume);

      _controllerListener = () {
        if (!mounted || _controller == null) return;

        final value = _controller!.value;
        if (value.hasError) {
          setState(() {
            _hasError = true;
          });
          return;
        }

        if (value.isCompleted) {
          _hideControlsTimer?.cancel();
          setState(() {
            _showControls = true;
          });
          _scheduleIdleDispose();
        } else if (mounted) {
          setState(() {});
        }
      };

      controller.addListener(_controllerListener!);

      if (!mounted) {
        controller.dispose();
        return;
      }

      _controller = controller;
      _activeInlinePlayer = this;

      setState(() {
        _isInitialized = true;
        _isInitializing = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _isInitialized = false;
        _hasError = true;
      });
      _disposeController();
    }
  }

  void _releaseOtherActiveInlinePlayer() {
    if (_activeInlinePlayer != null && !identical(_activeInlinePlayer, this)) {
      _activeInlinePlayer!._releaseResources(resetError: false);
    }
  }

  Future<void> _releaseResources({bool resetError = false}) async {
    _hideControlsTimer?.cancel();
    _disposeIdleTimer?.cancel();

    final controller = _controller;
    if (controller != null) {
      try {
        if (controller.value.isPlaying) {
          await controller.pause();
        }
      } catch (_) {}
    }

    _disposeController();

    if (!mounted) return;
    setState(() {
      _isInitialized = false;
      _isInitializing = false;
      _showControls = true;
      if (resetError) {
        _hasError = false;
      }
    });
  }

  void _disposeController() {
    final controller = _controller;
    final listener = _controllerListener;

    _controller = null;
    _controllerListener = null;

    if (controller != null && listener != null) {
      controller.removeListener(listener);
    }
    controller?.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();

    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;

    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _scheduleIdleDispose() {
    _disposeIdleTimer?.cancel();
    _disposeIdleTimer = Timer(const Duration(seconds: 20), () {
      final controller = _controller;
      if (!mounted || controller == null || controller.value.isPlaying) return;
      _releaseResources();
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  Future<void> _togglePlayPause() async {
    await _ensureInitialized();

    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    _disposeIdleTimer?.cancel();

    if (controller.value.isPlaying) {
      await controller.pause();
      _hideControlsTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _showControls = true;
      });
      _scheduleIdleDispose();
    } else {
      _releaseOtherActiveInlinePlayer();
      _activeInlinePlayer = this;
      await controller.play();
      if (!mounted) return;
      setState(() {
        _showControls = true;
      });
      _startHideControlsTimer();
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    final current = controller.value.position;
    final target = current + Duration(seconds: seconds);
    final duration = controller.value.duration;

    Duration clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (clamped > duration) clamped = duration;

    await controller.seekTo(clamped);
  }

  Future<void> _onSeekChanged(double valueMs) async {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    await controller.seekTo(Duration(milliseconds: valueMs.round()));
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    final controller = _controller;
    if (controller != null && _isInitialized) {
      await controller.setPlaybackSpeed(speed);
    }
    if (mounted) setState(() {});
  }

  Future<void> _setVolume(double volume) async {
    _volume = volume;
    final controller = _controller;
    if (controller != null && _isInitialized) {
      await controller.setVolume(volume);
    }
    if (mounted) setState(() {});
  }

  Future<void> _openFullscreen() async {
    await _ensureInitialized();

    if (!mounted) return;

    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    final navigator = Navigator.of(context);

    await navigator.push(
      MaterialPageRoute(
        builder: (context) => FullscreenVideoPlayerScreen(
          controller: controller,
          title: widget.media.title,
          initialSpeed: _playbackSpeed,
          initialVolume: _volume,
          onDownload: widget.onDownload,
          isDownloading: widget.isDownloading,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _showControls = true;
      _playbackSpeed = controller.value.playbackSpeed;
      _volume = controller.value.volume;
    });

    if (controller.value.isPlaying) {
      _startHideControlsTimer();
    } else {
      _scheduleIdleDispose();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildSeekBar(VideoPlayerController controller) {
    final durationMs = controller.value.duration.inMilliseconds.toDouble();
    final positionMs = controller.value.position.inMilliseconds
        .clamp(0, controller.value.duration.inMilliseconds)
        .toDouble();

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        value: durationMs <= 0 ? 0 : positionMs,
        min: 0,
        max: durationMs <= 0 ? 1 : durationMs,
        onChanged: _isInitialized
            ? (value) async {
                await _onSeekChanged(value);
              }
            : null,
      ),
    );
  }

  Widget _buildUninitializedPlayer() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 220,
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1F1F1F), Color(0xFF0F0F0F)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: _isInitializing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _togglePlayPause,
                          child: const SizedBox(
                            width: 72,
                            height: 72,
                            child: Icon(
                              Icons.play_arrow,
                              size: 38,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OverlayCircleButton(
                    onPressed: widget.isDownloading ? null : widget.onDownload,
                    child: widget.isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                  const SizedBox(width: 8),
                  _OverlayCircleButton(
                    onPressed: _openFullscreen,
                    child: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlinePlayer() {
    if (_hasError) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 36),
              const SizedBox(height: 12),
              const Text('Failed to load video'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                  });
                  _togglePlayPause();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUninitializedPlayer(),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            // child: Text(
            //   'Tap play to load this video',
            //   style: TextStyle(fontWeight: FontWeight.w500),
            // ),
          ),
        ],
      );
    }

    final controller = _controller!;
    final value = controller.value;
    final position = value.position > value.duration
        ? value.duration
        : value.position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: _toggleControls,
            child: AspectRatio(
              aspectRatio: value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
              child: Stack(
                children: [
                  Positioned.fill(child: VideoPlayer(controller)),
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(color: Colors.black26),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _InlineControlButton(
                              icon: Icons.replay_10,
                              onPressed: () => _seekRelative(-10),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: _togglePlayPause,
                              iconSize: 58,
                              color: Colors.white,
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _InlineControlButton(
                              icon: Icons.forward_10,
                              onPressed: () => _seekRelative(10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _OverlayCircleButton(
                            onPressed: widget.isDownloading
                                ? null
                                : widget.onDownload,
                            child: widget.isDownloading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.download,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          _OverlayCircleButton(
                            onPressed: _openFullscreen,
                            child: const Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildSeekBar(controller),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                '${_formatDuration(position)} / ${_formatDuration(value.duration)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              _CompactMenu<double>(
                label: '${_playbackSpeed}x',
                items: _speedOptions,
                onSelected: _setPlaybackSpeed,
                itemLabelBuilder: (speed) => '${speed}x',
              ),
              const SizedBox(width: 8),
              _CompactMenu<double>(
                label: '${(_volume * 100).round()}%',
                items: _volumeOptions,
                onSelected: _setVolume,
                icon: _volume == 0 ? Icons.volume_off : Icons.volume_up,
                itemLabelBuilder: (volume) => '${(volume * 100).round()}%',
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.media.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildInlinePlayer(),
          ],
        ),
      ),
    );
  }
}

class FullscreenVideoPlayerScreen extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  final double initialSpeed;
  final double initialVolume;
  final VoidCallback? onDownload;
  final bool isDownloading;

  const FullscreenVideoPlayerScreen({
    super.key,
    required this.controller,
    required this.title,
    required this.initialSpeed,
    required this.initialVolume,
    this.onDownload,
    this.isDownloading = false,
  });

  @override
  State<FullscreenVideoPlayerScreen> createState() =>
      _FullscreenVideoPlayerScreenState();
}

class _FullscreenVideoPlayerScreenState
    extends State<FullscreenVideoPlayerScreen> {
  bool _showControls = true;
  late double _playbackSpeed;
  late double _volume;
  Timer? _hideControlsTimer;

  final List<double> _speedOptions = [0.5, 1.0, 1.25, 1.5, 2.0];
  final List<double> _volumeOptions = [0.0, 0.25, 0.5, 0.75, 1.0];

  @override
  void initState() {
    super.initState();
    _playbackSpeed = widget.initialSpeed;
    _volume = widget.initialVolume;
    widget.controller.addListener(_listener);
    _enterFullscreenMode();
    _startHideControlsTimer();
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  Future<void> _enterFullscreenMode() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitFullscreenMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    widget.controller.removeListener(_listener);
    _exitFullscreenMode();
    super.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();

    if (!widget.controller.value.isPlaying) return;

    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _togglePlayPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
      _hideControlsTimer?.cancel();
      setState(() {
        _showControls = true;
      });
    } else {
      widget.controller.play();
      setState(() {
        _showControls = true;
      });
      _startHideControlsTimer();
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final current = widget.controller.value.position;
    final target = current + Duration(seconds: seconds);
    final duration = widget.controller.value.duration;

    Duration clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (clamped > duration) clamped = duration;

    await widget.controller.seekTo(clamped);
  }

  Future<void> _onSeekChanged(double valueMs) async {
    await widget.controller.seekTo(Duration(milliseconds: valueMs.round()));
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await widget.controller.setPlaybackSpeed(speed);
    if (mounted) setState(() {});
  }

  Future<void> _setVolume(double volume) async {
    _volume = volume;
    await widget.controller.setVolume(volume);
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildSeekBar() {
    final durationMs = widget.controller.value.duration.inMilliseconds
        .toDouble();
    final positionMs = widget.controller.value.position.inMilliseconds
        .clamp(0, widget.controller.value.duration.inMilliseconds)
        .toDouble();

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        value: durationMs <= 0 ? 0 : positionMs,
        min: 0,
        max: durationMs <= 0 ? 1 : durationMs,
        onChanged: (value) async {
          await _onSeekChanged(value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final position = value.position > value.duration
        ? value.duration
        : value.position;
    final aspectRatio = value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _exitFullscreenMode();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: VideoPlayer(widget.controller),
                ),
              ),
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(color: Colors.black26),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              await _exitFullscreenMode();
                              if (!mounted) return;
                              navigator.pop();
                            },
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: widget.isDownloading
                                ? null
                                : widget.onDownload,
                            icon: widget.isDownloading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.download,
                                    color: Colors.white,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: const Offset(0, -8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FullscreenControlButton(
                              icon: Icons.replay_10,
                              size: 42,
                              onPressed: () => _seekRelative(-10),
                            ),
                            const SizedBox(width: 28),
                            _FullscreenControlButton(
                              icon: value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              size: 78,
                              onPressed: _togglePlayPause,
                            ),
                            const SizedBox(width: 28),
                            _FullscreenControlButton(
                              icon: Icons.forward_10,
                              size: 42,
                              onPressed: () => _seekRelative(10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSeekBar(),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_formatDuration(position)} / ${_formatDuration(value.duration)}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              _CompactMenu<double>(
                                label: '${_playbackSpeed}x',
                                items: _speedOptions,
                                onSelected: _setPlaybackSpeed,
                                itemLabelBuilder: (speed) => '${speed}x',
                                filled: true,
                              ),
                              const SizedBox(width: 8),
                              _CompactMenu<double>(
                                label: '${(_volume * 100).round()}%',
                                items: _volumeOptions,
                                onSelected: _setVolume,
                                icon: _volume == 0
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                itemLabelBuilder: (volume) =>
                                    '${(volume * 100).round()}%',
                                filled: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayCircleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _OverlayCircleButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(width: 36, height: 36, child: Center(child: child)),
      ),
    );
  }
}

class _InlineControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _InlineControlButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _FullscreenControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  const _FullscreenControlButton({
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      iconSize: size,
      splashRadius: size * 0.6,
      icon: Icon(icon, color: Colors.white),
    );
  }
}

class _CompactMenu<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final Future<void> Function(T value) onSelected;
  final String Function(T value) itemLabelBuilder;
  final IconData? icon;
  final bool filled;

  const _CompactMenu({
    required this.label,
    required this.items,
    required this.onSelected,
    required this.itemLabelBuilder,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: (value) async {
        await onSelected(value);
      },
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem<T>(
              value: item,
              child: Text(itemLabelBuilder(item)),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? Colors.white : null,
          border: filled ? null : Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: filled ? Colors.black : Colors.black87,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: filled ? Colors.black : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
