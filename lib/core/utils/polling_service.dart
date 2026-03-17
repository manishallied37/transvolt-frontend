import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';

class PollingService with WidgetsBindingObserver {
  Timer? _timer;
  Duration _currentInterval;
  final Duration _baseInterval;
  final Duration _maxInterval;
  Future<void> Function()? _task;
  bool _running = false;

  PollingService({
    Duration baseInterval = const Duration(seconds: 30),
    Duration maxInterval = const Duration(minutes: 5),
  }) : _baseInterval = baseInterval,
       _currentInterval = baseInterval,
       _maxInterval = maxInterval;

  void start({required Future<void> Function() task}) {
    _task = task;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _schedule() {
    _timer?.cancel();
    if (!_running) return;

    _timer = Timer(_currentInterval, () async {
      if (!_running) return;
      try {
        await _task?.call();
        // Success — reset to base interval
        _currentInterval = _baseInterval;
      } catch (e) {
        debugPrint('Polling error: $e');
        // Exponential backoff: double interval up to max
        _currentInterval = Duration(
          milliseconds: min(
            _currentInterval.inMilliseconds * 2,
            _maxInterval.inMilliseconds,
          ),
        );
      }
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // App backgrounded — pause polling
      _timer?.cancel();
      _timer = null;
    } else if (state == AppLifecycleState.resumed && _running) {
      // App foregrounded — resume polling immediately
      _currentInterval = _baseInterval;
      _schedule();
    }
  }
}
