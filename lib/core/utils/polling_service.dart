import 'dart:async';

import 'package:flutter/widgets.dart';

class PollingService {
  Timer? _timer;

  void start({
    required Duration interval,
    required Future<void> Function() task,
  }) {
    _timer = Timer.periodic(interval, (timer) async {
      try {
        await task();
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    });
  }

  void stop() {
    _timer?.cancel();
  }
}
