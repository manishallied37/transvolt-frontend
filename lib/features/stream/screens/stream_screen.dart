import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/config/rbac.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/rbac_guard.dart';
import '../../auth/services/auth_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

/// Default auto-stop: 5 min (matches backend cap of 300 s).
const int _kDefaultAutoStopSeconds = 300;

/// Mock vehicles — replace with real API call when Netradyne provides the list.
const List<_Vehicle> _kMockVehicles = [
  _Vehicle(id: 'VH-001', label: 'MH12 AB 1234'),
  _Vehicle(id: 'VH-002', label: 'MH14 CD 5678'),
  _Vehicle(id: 'VH-003', label: 'MH01 EF 9012'),
  _Vehicle(id: 'VH-004', label: 'DL 3C AB 3456'),
  _Vehicle(id: 'VH-005', label: 'KA 01 MN 7890'),
];

// ─── Models ──────────────────────────────────────────────────────────────────

class _Vehicle {
  final String id;
  final String label;
  const _Vehicle({required this.id, required this.label});
}

class _StreamSession {
  final String sessionId;
  final String vehicleId;
  final String streamUrl;
  final DateTime expiresAt;
  final int autoStopAfterSeconds;

  const _StreamSession({
    required this.sessionId,
    required this.vehicleId,
    required this.streamUrl,
    required this.expiresAt,
    required this.autoStopAfterSeconds,
  });
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class StreamScreen extends ConsumerStatefulWidget {
  const StreamScreen({super.key});

  @override
  ConsumerState<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends ConsumerState<StreamScreen> {
  _Vehicle? _selectedVehicle;
  _StreamSession? _session;
  bool _loading = false;
  String? _error;

  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  VideoPlayerController? _videoController;
  bool _videoInitialised = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _startStream() async {
    if (_selectedVehicle == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await AuthService.dio.post(
        '${AppConstants.apiNetradyne}/v1/stream/${_selectedVehicle!.id}/start',
        queryParameters: {'durationSeconds': _kDefaultAutoStopSeconds},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final session = _StreamSession(
        sessionId: data['sessionId'] as String,
        vehicleId: data['vehicleId'] as String,
        streamUrl: data['streamUrl'] as String,
        expiresAt: DateTime.parse(data['expiresAt'] as String),
        autoStopAfterSeconds: data['autoStopAfterSeconds'] as int,
      );

      await _initVideo(session.streamUrl);

      setState(() {
        _session = session;
        _remainingSeconds = session.autoStopAfterSeconds;
        _loading = false;
      });
      _startCountdown();
    } on DioException catch (e) {
      setState(() {
        _error =
            e.response?.data?['message']?.toString() ??
            'Failed to start stream';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unexpected error. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _stopStream() async {
    _countdownTimer?.cancel();
    if (_session != null) {
      try {
        await AuthService.dio.post(
          '${AppConstants.apiNetradyne}/v1/stream/${_session!.sessionId}/stop',
        );
      } catch (_) {
        /* best-effort */
      }
    }
    await _videoController?.pause();
    _videoController?.dispose();
    setState(() {
      _session = null;
      _videoController = null;
      _videoInitialised = false;
      _remainingSeconds = 0;
      _error = null;
    });
  }

  Future<void> _initVideo(String url) async {
    _videoController?.dispose();
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    await c.initialize();
    await c.setLooping(true);
    await c.play();
    if (mounted) {
      setState(() {
        _videoController = c;
        _videoInitialised = true;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        t.cancel();
        _stopStream();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RbacScreen(
      roles: {AppRole.superAdmin, AppRole.authority, AppRole.commandCenter},
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Live Stream',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: Colors.black12),
          ),
          actions: [
            if (_session != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: _CountdownBadge(remaining: _remainingSeconds),
              ),
          ],
        ),
        body: SafeArea(
          child: _session != null ? _buildActiveStream() : _buildSelector(),
        ),
      ),
    );
  }

  Widget _buildSelector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Vehicle',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a vehicle to begin live streaming from its camera.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          ..._kMockVehicles.map(
            (v) => _VehicleTile(
              vehicle: v,
              selected: _selectedVehicle?.id == v.id,
              onTap: () => setState(() => _selectedVehicle = v),
            ),
          ),

          const SizedBox(height: 24),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFCEBEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Color(0xFFA32D2D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFA32D2D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedVehicle == null || _loading
                  ? null
                  : _startStream,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.videocam_rounded, size: 18),
              label: Text(_loading ? 'Connecting...' : 'Start Live Stream'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: Colors.black38),
              const SizedBox(width: 4),
              Text(
                'Stream auto-stops after ${_kDefaultAutoStopSeconds ~/ 60} minutes',
                style: const TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStream() {
    return Column(
      children: [
        // 16:9 video player
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: _videoInitialised && _videoController != null
                ? VideoPlayer(_videoController!)
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _fmt(_remainingSeconds),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'remaining',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: 'Vehicle',
                        value: _selectedVehicle?.label ?? '—',
                      ),
                      const SizedBox(height: 6),
                      _InfoRow(label: 'Session', value: _session!.sessionId),
                      const SizedBox(height: 6),
                      _InfoRow(
                        label: 'Expires at',
                        value: TimeOfDay.fromDateTime(
                          _session!.expiresAt.toLocal(),
                        ).format(context),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Progress bar
                LinearProgressIndicator(
                  value: _remainingSeconds / _session!.autoStopAfterSeconds,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  backgroundColor: Colors.black12,
                  color: _remainingSeconds < 60 ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 6),
                Text(
                  _remainingSeconds < 60
                      ? 'Stream ending soon'
                      : 'Auto-stops in ${_fmt(_remainingSeconds)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _remainingSeconds < 60 ? Colors.red : Colors.black38,
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _stopStream,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('Stop Stream'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _VehicleTile extends StatelessWidget {
  final _Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;
  const _VehicleTile({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F1FB) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF185FA5) : Colors.black12,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.directions_bus_outlined,
              size: 20,
              color: selected ? const Color(0xFF185FA5) : Colors.black45,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                vehicle.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? const Color(0xFF185FA5) : Colors.black87,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: Color(0xFF185FA5),
              ),
          ],
        ),
      ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  final int remaining;
  const _CountdownBadge({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final urgent = remaining < 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFCEBEB) : const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: urgent ? const Color(0xFFA32D2D) : const Color(0xFF3B6D11),
          ),
          const SizedBox(width: 4),
          Text(
            '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: urgent ? const Color(0xFFA32D2D) : const Color(0xFF3B6D11),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black45),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
