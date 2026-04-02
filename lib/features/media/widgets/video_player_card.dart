import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/event_models.dart';

class VideoPlayerCard extends StatefulWidget {
  final MediaItem media;
  final VoidCallback? onDownload;
  final bool isDownloading;
  final bool isLivestream;
  final ValueChanged<bool>? onFullscreenChanged;
  final VoidCallback? onPlaybackStarted;

  const VideoPlayerCard({
    super.key,
    required this.media,
    this.onDownload,
    this.isDownloading = false,
    this.isLivestream = false,
    this.onFullscreenChanged,
    this.onPlaybackStarted,
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
  bool _showVolumeSlider = false;
  bool _isInFullscreen = false; // true while fullscreen route is open
  double _playbackSpeed = 1.0;
  double _volume = 1.0;

  // Seek ripple feedback
  int? _seekRipple; // -1 = backward, 1 = forward
  Timer? _seekRippleTimer;

  Timer? _hideControlsTimer;
  Timer? _disposeIdleTimer;
  Timer? _liveElapsedTimer;
  Duration _liveElapsed = Duration.zero;
  bool _didNotifyPlaybackStarted = false;

  final List<double> _speedOptions = [0.5, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    if (widget.isLivestream) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureInitialized();
      });
    }
  }

  @override
  void dispose() {
    if (identical(_activeInlinePlayer, this)) _activeInlinePlayer = null;
    _hideControlsTimer?.cancel();
    _disposeIdleTimer?.cancel();
    _liveElapsedTimer?.cancel();
    _seekRippleTimer?.cancel();
    // FIX 1: For livestream, if fullscreen is still open the controller is
    // being used by FullscreenVideoPlayerScreen. Don't dispose it here —
    // FullscreenVideoPlayerScreen will call _safeExit which pops first.
    // Only dispose when we actually own it exclusively.
    if (!_isInFullscreen) {
      _disposeController();
    } else {
      // Just detach the listener; fullscreen will dispose nothing since it
      // doesn't own the controller.
      final controller = _controller;
      final listener = _controllerListener;
      _controller = null;
      _controllerListener = null;
      if (controller != null && listener != null) {
        controller.removeListener(listener);
      }
      // Schedule disposal after fullscreen is done
      Future.microtask(() => controller?.dispose());
    }
    super.dispose();
  }

  // ── Live elapsed ticker ────────────────────────────────────────────────────

  void _startLiveElapsedTicker() {
    _liveElapsedTimer?.cancel();
    _liveElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final c = _controller;
      if (c != null && c.value.isPlaying) {
        setState(() => _liveElapsed = c.value.position);
      }
    });
  }

  void _stopLiveElapsedTicker() => _liveElapsedTimer?.cancel();

  // ── Init / teardown ────────────────────────────────────────────────────────

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
      if (!widget.isLivestream) {
        await controller.setPlaybackSpeed(_playbackSpeed);
      }
      await controller.setVolume(_volume);

      _controllerListener = () {
        if (!mounted || _controller == null) return;
        final value = _controller!.value;
        if (value.hasError) {
          // FIX 1: For livestream errors, don't show error UI — the parent
          // expiry timer will clean up. Just silently release.
          if (widget.isLivestream) {
            _releaseResources();
          } else {
            setState(() => _hasError = true);
          }
          return;
        }

        if (widget.isLivestream &&
            value.isPlaying &&
            !_didNotifyPlaybackStarted) {
          _didNotifyPlaybackStarted = true;
          widget.onPlaybackStarted?.call();
        }

        if (value.isCompleted) {
          _hideControlsTimer?.cancel();
          _stopLiveElapsedTicker();
          setState(() => _showControls = true);
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

      if (widget.isLivestream) {
        await controller.play();
        _startLiveElapsedTicker();
        _startHideControlsTimer();
      }
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
    _stopLiveElapsedTicker();

    final controller = _controller;
    if (controller != null) {
      try {
        if (controller.value.isPlaying) await controller.pause();
      } catch (_) {}
    }

    _disposeController();

    if (!mounted) return;
    setState(() {
      _isInitialized = false;
      _isInitializing = false;
      _showControls = true;
      _liveElapsed = Duration.zero;
      if (resetError) _hasError = false;
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

  // ── Controls ───────────────────────────────────────────────────────────────

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
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
      if (!_showControls) _showVolumeSlider = false;
    });
    if (_showControls) _startHideControlsTimer();
  }

  Future<void> _togglePlayPause() async {
    if (widget.isLivestream) return;
    await _ensureInitialized();
    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    _disposeIdleTimer?.cancel();

    if (controller.value.isPlaying) {
      await controller.pause();
      _hideControlsTimer?.cancel();
      if (!mounted) return;
      setState(() => _showControls = true);
      _scheduleIdleDispose();
    } else {
      _releaseOtherActiveInlinePlayer();
      _activeInlinePlayer = this;
      await controller.play();
      if (!mounted) return;
      setState(() => _showControls = true);
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

    // Show ripple feedback
    _seekRippleTimer?.cancel();
    setState(() => _seekRipple = seconds > 0 ? 1 : -1);
    _seekRippleTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekRipple = null);
    });
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

  // FIX 4: Smooth fullscreen transition using custom PageRouteBuilder (fade+scale)
  Future<void> _openFullscreen() async {
    await _ensureInitialized();
    if (!mounted) return;
    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    widget.onFullscreenChanged?.call(true);
    setState(() => _isInFullscreen = true);

    final navigator = Navigator.of(context);
    await navigator.push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullscreenVideoPlayerScreen(
              controller: controller,
              title: widget.media.title,
              initialSpeed: _playbackSpeed,
              initialVolume: _volume,
              onDownload: widget.onDownload,
              isDownloading: widget.isDownloading,
              isLivestream: widget.isLivestream,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );

    setState(() => _isInFullscreen = false);
    widget.onFullscreenChanged?.call(false);

    if (!mounted) return;
    setState(() {
      _showControls = true;
      _playbackSpeed = controller.value.playbackSpeed;
      _volume = controller.value.volume;
    });

    if (controller.value.isPlaying) {
      if (widget.isLivestream) _startLiveElapsedTicker();
      _startHideControlsTimer();
    } else {
      if (!widget.isLivestream) _scheduleIdleDispose();
    }
  }

  // ── Formatters ─────────────────────────────────────────────────────────────

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

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildSeekBar(VideoPlayerController controller) {
    final durationMs = controller.value.duration.inMilliseconds.toDouble();
    final positionMs = controller.value.position.inMilliseconds
        .clamp(0, controller.value.duration.inMilliseconds)
        .toDouble();

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: Theme.of(context).colorScheme.primary,
        thumbColor: Theme.of(context).colorScheme.primary,
      ),
      child: Slider(
        value: durationMs <= 0 ? 0 : positionMs,
        min: 0,
        max: durationMs <= 0 ? 1 : durationMs,
        onChanged: _isInitialized
            ? (value) async => await _onSeekChanged(value)
            : null,
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFCC0000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // FIX 2: Volume slider constrained to fixed width, not full video width
  Widget _buildVolumeSliderRow({bool large = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _showVolumeSlider = !_showVolumeSlider);
            _hideControlsTimer?.cancel();
          },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              _volume == 0 ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
              size: large ? 24 : 20,
            ),
          ),
        ),
        if (_showVolumeSlider)
          SizedBox(
            width: 100, // FIX 2: fixed width, not Expanded
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white38,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
              ),
              child: Slider(
                value: _volume,
                min: 0,
                max: 1,
                onChanged: (v) => _setVolume(v),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLiveBottomBar(VideoPlayerController controller) {
    final isPlaying = controller.value.isPlaying;
    final elapsed = isPlaying ? _liveElapsed : controller.value.position;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          _buildLiveBadge(),
          const SizedBox(width: 10),
          Text(
            _formatDuration(elapsed),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          _buildVolumeSliderRow(),
          const SizedBox(width: 4),
          _OverlayCircleButton(
            onPressed: _openFullscreen,
            child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  // ── Seek ripple overlay ────────────────────────────────────────────────────

  Widget _buildSeekRipple() {
    if (_seekRipple == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: Row(
        children: [
          if (_seekRipple == -1)
            Expanded(
              child: Container(
                color: Colors.white12,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.replay_10, color: Colors.white, size: 36),
                      SizedBox(height: 4),
                      Text(
                        '10s',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
          if (_seekRipple == 1)
            Expanded(
              child: Container(
                color: Colors.white12,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forward_10, color: Colors.white, size: 36),
                      SizedBox(height: 4),
                      Text(
                        '10s',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  // ── Uninitialized player ──────────────────────────────────────────────────

  Widget _buildUninitializedPlayer() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 220,
        width: double.infinity,
        color: const Color(0xFFEFF1F5),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF4F5F8), Color(0xFFE4E7EE)],
                  ),
                ),
              ),
            ),
            if (widget.isLivestream)
              Positioned(top: 10, left: 10, child: _buildLiveBadge()),
            Positioned.fill(
              child: Center(
                child: _isInitializing
                    ? const CircularProgressIndicator(color: Color(0xFF534AB7))
                    : Material(
                        color: Colors.white.withValues(alpha: 0.95),
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
                              color: Color(0xFF534AB7),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            if (!widget.isLivestream)
              Positioned(
                top: 8,
                right: 8,
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
            if (widget.isLivestream)
              Positioned(
                top: 8,
                right: 8,
                child: _OverlayCircleButton(
                  onPressed: _openFullscreen,
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Main inline player ─────────────────────────────────────────────────────

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
                  setState(() => _hasError = false);
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
      return _buildUninitializedPlayer();
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
            // FIX 5: double-tap left/right to seek ±10s
            onDoubleTapDown: widget.isLivestream
                ? null
                : (details) {
                    final halfWidth = context.size?.width ?? 300;
                    if (details.localPosition.dx < halfWidth / 2) {
                      _seekRelative(-10);
                    } else {
                      _seekRelative(10);
                    }
                  },
            child: AspectRatio(
              aspectRatio: widget.isLivestream
                  ? 16 / 9
                  : (value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio),
              child: Stack(
                children: [
                  Positioned.fill(child: VideoPlayer(controller)),

                  // Gradient for live bottom readability
                  if (widget.isLivestream)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 80,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                      ),
                    ),

                  // Dim overlay
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(color: Colors.black26),
                    ),
                  ),

                  // Seek ripple feedback (VOD only)
                  if (!widget.isLivestream) _buildSeekRipple(),

                  // VOD: centre controls
                  if (!widget.isLivestream)
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

                  // VOD: top-right download + fullscreen
                  if (!widget.isLivestream)
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

                  // Live: bottom bar
                  if (widget.isLivestream)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: _buildLiveBottomBar(controller),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // VOD: seek bar + time / speed / volume below video
        if (!widget.isLivestream) ...[
          const SizedBox(height: 6),
          _buildSeekBar(controller),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(value.duration)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                _CompactMenu<double>(
                  label: '${_playbackSpeed}x',
                  items: _speedOptions,
                  onSelected: _setPlaybackSpeed,
                  itemLabelBuilder: (speed) => '${speed}x',
                ),
                const SizedBox(width: 8),
                _VolumeMenu(volume: _volume, onChanged: _setVolume),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLivestream) return _buildInlinePlayer();

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

// ── Pulsing red dot ──────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ── Fullscreen player ─────────────────────────────────────────────────────────

class FullscreenVideoPlayerScreen extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  final double initialSpeed;
  final double initialVolume;
  final VoidCallback? onDownload;
  final bool isDownloading;
  final bool isLivestream;

  const FullscreenVideoPlayerScreen({
    super.key,
    required this.controller,
    required this.title,
    required this.initialSpeed,
    required this.initialVolume,
    this.onDownload,
    this.isDownloading = false,
    this.isLivestream = false,
  });

  @override
  State<FullscreenVideoPlayerScreen> createState() =>
      _FullscreenVideoPlayerScreenState();
}

class _FullscreenVideoPlayerScreenState
    extends State<FullscreenVideoPlayerScreen> {
  bool _showControls = true;
  bool _showVolumeSlider = false;
  late double _playbackSpeed;
  late double _volume;
  Timer? _hideControlsTimer;
  Timer? _liveElapsedTimer;
  Duration _liveElapsed = Duration.zero;

  // Seek ripple
  int? _seekRipple;
  Timer? _seekRippleTimer;

  final List<double> _speedOptions = [0.5, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _playbackSpeed = widget.initialSpeed;
    _volume = widget.initialVolume;
    widget.controller.addListener(_listener);
    _enterFullscreenMode();
    _startHideControlsTimer();
    if (widget.isLivestream && widget.controller.value.isPlaying) {
      _startLiveElapsedTicker();
    }
  }

  void _listener() {
    if (!mounted) return;
    final value = widget.controller.value;
    // FIX 1: On error or stream end in fullscreen, exit cleanly
    if (value.hasError) {
      _safeExit();
      return;
    }
    setState(() {});
  }

  void _safeExit() {
    if (!mounted) return;
    _hideControlsTimer?.cancel();
    _liveElapsedTimer?.cancel();
    _exitFullscreenMode().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _startLiveElapsedTicker() {
    _liveElapsedTimer?.cancel();
    _liveElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.controller.value.isPlaying) {
        setState(() => _liveElapsed = widget.controller.value.position);
      }
    });
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
    _liveElapsedTimer?.cancel();
    _seekRippleTimer?.cancel();
    widget.controller.removeListener(_listener);
    _exitFullscreenMode();
    super.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!widget.controller.value.isPlaying) return;
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (!_showControls) _showVolumeSlider = false;
    });
    if (_showControls) _startHideControlsTimer();
  }

  void _togglePlayPause() {
    if (widget.isLivestream) return;
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
      _hideControlsTimer?.cancel();
      _liveElapsedTimer?.cancel();
      setState(() => _showControls = true);
    } else {
      widget.controller.play();
      setState(() => _showControls = true);
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

    _seekRippleTimer?.cancel();
    setState(() => _seekRipple = seconds > 0 ? 1 : -1);
    _seekRippleTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekRipple = null);
    });
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

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFCC0000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar() {
    final durationMs = widget.controller.value.duration.inMilliseconds
        .toDouble();
    final positionMs = widget.controller.value.position.inMilliseconds
        .clamp(0, widget.controller.value.duration.inMilliseconds)
        .toDouble();

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white38,
        thumbColor: Colors.white,
      ),
      child: Slider(
        value: durationMs <= 0 ? 0 : positionMs,
        min: 0,
        max: durationMs <= 0 ? 1 : durationMs,
        onChanged: (value) async => await _onSeekChanged(value),
      ),
    );
  }

  // FIX 2: Volume slider constrained, not full width
  Widget _buildVolumeRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _showVolumeSlider = !_showVolumeSlider);
            _hideControlsTimer?.cancel();
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              _volume == 0 ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        if (_showVolumeSlider)
          SizedBox(
            width: 120, // FIX 2: fixed width
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white38,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
              ),
              child: Slider(
                value: _volume,
                min: 0,
                max: 1,
                onChanged: (v) => _setVolume(v),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSeekRipple() {
    if (_seekRipple == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: Row(
        children: [
          if (_seekRipple == -1)
            Expanded(
              child: Container(
                color: Colors.white12,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.replay_10, color: Colors.white, size: 48),
                      SizedBox(height: 6),
                      Text(
                        '10s',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
          if (_seekRipple == 1)
            Expanded(
              child: Container(
                color: Colors.white12,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forward_10, color: Colors.white, size: 48),
                      SizedBox(height: 6),
                      Text(
                        '10s',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final position = value.position > value.duration
        ? value.duration
        : value.position;
    final aspectRatio = widget.isLivestream
        ? 16 / 9
        : (value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio);
    final elapsed = value.isPlaying ? _liveElapsed : value.position;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) await _exitFullscreenMode();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          // FIX 5: double-tap to seek in fullscreen
          onDoubleTapDown: widget.isLivestream
              ? null
              : (details) {
                  final halfWidth = MediaQuery.of(context).size.width / 2;
                  if (details.localPosition.dx < halfWidth) {
                    _seekRelative(-10);
                  } else {
                    _seekRelative(10);
                  }
                },
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: VideoPlayer(widget.controller),
                ),
              ),

              // Bottom gradient (live)
              if (widget.isLivestream)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 120,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                  ),
                ),

              // Dim overlay
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(color: Colors.black26),
                ),
              ),

              // FIX 3: REMOVED the standalone top-left LIVE badge — bottom bar has it

              // Seek ripple
              if (!widget.isLivestream) _buildSeekRipple(),

              // Top bar
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
                          if (!widget.isLivestream)
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

              // Centre controls (VOD only)
              if (!widget.isLivestream)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Align(
                        alignment: Alignment.center,
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

              // Bottom bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: SafeArea(
                    top: false,
                    child: widget.isLivestream
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                _buildLiveBadge(),
                                const SizedBox(width: 10),
                                Text(
                                  _formatDuration(elapsed),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                _buildVolumeRow(),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildSeekBar(),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${_formatDuration(position)} / ${_formatDuration(value.duration)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    _CompactMenu<double>(
                                      label: '${_playbackSpeed}x',
                                      items: _speedOptions,
                                      onSelected: _setPlaybackSpeed,
                                      itemLabelBuilder: (s) => '${s}x',
                                      filled: true,
                                    ),
                                    const SizedBox(width: 8),
                                    _VolumeMenu(
                                      volume: _volume,
                                      onChanged: _setVolume,
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

// ── Shared small widgets ──────────────────────────────────────────────────────

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
      onSelected: (value) async => await onSelected(value),
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

class _VolumeMenu extends StatelessWidget {
  final double volume;
  final Future<void> Function(double) onChanged;
  final bool filled;

  const _VolumeMenu({
    required this.volume,
    required this.onChanged,
    this.filled = false,
  });

  static const List<double> _options = [0.0, 0.25, 0.5, 0.75, 1.0];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      onSelected: (v) async => await onChanged(v),
      itemBuilder: (context) => _options
          .map(
            (v) => PopupMenuItem<double>(
              value: v,
              child: Text('${(v * 100).round()}%'),
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
            Icon(
              volume == 0 ? Icons.volume_off : Icons.volume_up,
              size: 16,
              color: filled ? Colors.black : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              '${(volume * 100).round()}%',
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
