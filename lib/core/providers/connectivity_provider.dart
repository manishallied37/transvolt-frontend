import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityNotifier extends AsyncNotifier<bool> {
  StreamSubscription? _sub;

  @override
  Future<bool> build() async {
    final result = await Connectivity().checkConnectivity();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      state = AsyncData(online);
    });

    ref.onDispose(() => _sub?.cancel());

    return result.any((r) => r != ConnectivityResult.none);
  }
}

final connectivityProvider = AsyncNotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);

// Simple sync bool — defaults to true until first check completes
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).asData?.value ?? true;
});
