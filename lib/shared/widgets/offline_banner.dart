import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/connectivity_provider.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    if (isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: const Color(0xFF2C2C2A),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 16),
          SizedBox(width: 8),
          Text(
            'No internet connection',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
