import 'dart:async';

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
        print("Polling error: $e");
      }
    });
  }

  void stop() {
    _timer?.cancel();
  }
}
