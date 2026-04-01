import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../media/models/event_models.dart';
import '../../media/widgets/video_player_card.dart';
import '../services/livestream_api.dart';
import '../services/vehicle_service.dart';

// ---------------------------------------------------------------------------
// StreamScreenLaunchArgs
// ---------------------------------------------------------------------------
class StreamScreenLaunchArgs {
  const StreamScreenLaunchArgs({
    this.vehicleNumber,
    this.vin,
    this.licensePlateNumber,
    this.cameraId,
    this.driverName,
    this.latestEventType,
    this.latestSeverity,
    this.latestLocation,
    this.autoPlay = true,
    this.prefillSearch = true,
  });

  final String? vehicleNumber;
  final String? vin;
  final String? licensePlateNumber;
  final String? cameraId;

  final String? driverName;
  final String? latestEventType;
  final String? latestSeverity;
  final String? latestLocation;

  final bool autoPlay;
  final bool prefillSearch;

  bool get hasVehicleHint {
    return _normalized(vehicleNumber).isNotEmpty ||
        _normalized(vin).isNotEmpty ||
        _normalized(licensePlateNumber).isNotEmpty ||
        _normalized(cameraId).isNotEmpty;
  }

  bool get isFullyResolved {
    final hasVehicleId =
        _normalized(vehicleNumber).isNotEmpty ||
        _normalized(vin).isNotEmpty ||
        _normalized(licensePlateNumber).isNotEmpty;
    return hasVehicleId && _normalized(cameraId).isNotEmpty;
  }

  static String _normalized(String? value) =>
      (value ?? '').trim().toLowerCase();
}

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key, this.launchArgs});

  final StreamScreenLaunchArgs? launchArgs;

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isStartingStream = false;
  bool _didResolveRouteArgs = false;
  bool _didHandleInitialLaunch = false;
  bool _isFullscreen = false;
  bool _streamExpired = false;

  String? _errorMessage;

  List<_VehicleOption> _vehicleOptions = <_VehicleOption>[];
  List<_VehicleOption> _filteredOptions = <_VehicleOption>[];
  List<_VehicleOption> _allVehicleOptions = <_VehicleOption>[];

  _VehicleOption? _selectedVehicle;
  MediaItem? _activeStream;
  String? _streamStatus;
  Timer? _streamExpiryTimer;
  Timer? _countdownTimer;
  String? _activeStreamVehicleKey;
  DateTime? _streamExpiryTime;
  int _remainingSeconds = 0;
  bool _hasPlaybackStarted = false;

  StreamScreenLaunchArgs? _pendingLaunchArgs;

  @override
  void initState() {
    super.initState();
    _pendingLaunchArgs = widget.launchArgs;
    _searchController.addListener(_applySearchFilter);
    _loadVehicles();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didResolveRouteArgs) return;
    _didResolveRouteArgs = true;
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is StreamScreenLaunchArgs) {
      _pendingLaunchArgs ??= routeArgs;
    }
  }

  @override
  void dispose() {
    _streamExpiryTimer?.cancel();
    _countdownTimer?.cancel();
    _searchController
      ..removeListener(_applySearchFilter)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _activeStream = null;
      _streamStatus = null;
      _streamExpired = false;
      _streamExpiryTime = null;
      _remainingSeconds = 0;
      _hasPlaybackStarted = false;
    });

    try {
      final args = _pendingLaunchArgs;

      if (args != null && args.isFullyResolved) {
        final label = _pickFirstNonEmpty([args.vehicleNumber, args.vin, 'Vehicle']);
        final key = _pickFirstNonEmpty([args.vehicleNumber, args.vin, args.licensePlateNumber]);

        final syntheticVehicle = _VehicleOption(
          key: key,
          label: label,
          event: {},
          vehicleNumber: args.vehicleNumber ?? '',
          vin: args.vin ?? '',
          licensePlateNumber: args.licensePlateNumber ?? '',
          driverName: args.driverName ?? '',
          driverId: '',
          cameraId: args.cameraId ?? '',
          latestEventType: args.latestEventType ?? '',
          latestSeverity: args.latestSeverity ?? '',
          latestStatus: '',
          latestTimestamp: DateTime.now(),
          latestLocation: args.latestLocation ?? '',
        );

        final allVehicles = await VehicleService.getVehicles();
        final allOptions = _buildOptions(allVehicles);

        setState(() {
          _allVehicleOptions = allOptions;
          _vehicleOptions = [syntheticVehicle];
          _filteredOptions = [syntheticVehicle];
          _selectedVehicle = syntheticVehicle;
        });

        await _handleLaunchFlowIfNeeded();
        return;
      }

      final vehicles = await VehicleService.getVehicles();
      final options = _buildOptions(vehicles);
      final launchMatch = _findBestVehicleMatch(options, _pendingLaunchArgs);
      final bool launchedFromEvent =
          _pendingLaunchArgs != null && _pendingLaunchArgs!.hasVehicleHint;
      final initialSelection = launchedFromEvent
          ? launchMatch
          : (options.isNotEmpty ? options.first : null);

      setState(() {
        _allVehicleOptions = options;
        _vehicleOptions = options;
        _filteredOptions = List<_VehicleOption>.from(options);
        _selectedVehicle = initialSelection;
      });

      if (initialSelection != null &&
          _pendingLaunchArgs?.prefillSearch == true &&
          _pendingLaunchArgs?.hasVehicleHint == true) {
        _setSearchTextSilently(initialSelection.label);
        _applySearchFilter();
      }

      await _handleLaunchFlowIfNeeded();
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to load vehicles: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLaunchFlowIfNeeded() async {
    if (_didHandleInitialLaunch) return;
    final args = _pendingLaunchArgs;
    if (args == null) return;

    _didHandleInitialLaunch = true;
    if (!args.hasVehicleHint) return;

    final matchedVehicle = _findBestVehicleMatch(_vehicleOptions, args);
    if (matchedVehicle == null) {
      if (!mounted) return;
      setState(() {
        _selectedVehicle = null;
        _activeStream = null;
        _streamStatus = 'Vehicle not found for livestream launch.';
      });
      return;
    }

    if (_selectedVehicle?.key != matchedVehicle.key) {
      setState(() {
        _selectedVehicle = matchedVehicle;
        _activeStream = null;
        _streamStatus = null;
      });
    }

    if (args.prefillSearch) {
      _setSearchTextSilently(matchedVehicle.label);
      _applySearchFilter();
    }

    if (!args.autoPlay) return;

    if (matchedVehicle.cameraId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _streamStatus = 'Camera ID is unavailable for ${matchedVehicle.label}.';
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startLivestream();
    });
  }

  _VehicleOption? _findBestVehicleMatch(
    List<_VehicleOption> options,
    StreamScreenLaunchArgs? args,
  ) {
    if (args == null || options.isEmpty) return null;

    final vehicleNumber = _normalize(args.vehicleNumber);
    final vin = _normalize(args.vin);
    final licensePlate = _normalize(args.licensePlateNumber);
    final cameraId = _normalize(args.cameraId);

    int score(_VehicleOption option) {
      var total = 0;
      if (vehicleNumber.isNotEmpty && _normalize(option.vehicleNumber) == vehicleNumber) total += 100;
      if (vin.isNotEmpty && _normalize(option.vin) == vin) total += 90;
      if (licensePlate.isNotEmpty && _normalize(option.licensePlateNumber) == licensePlate) total += 80;
      if (cameraId.isNotEmpty && _normalize(option.cameraId) == cameraId) total += 70;
      return total;
    }

    _VehicleOption? best;
    var bestScore = 0;
    for (final option in options) {
      final currentScore = score(option);
      if (currentScore > bestScore) {
        best = option;
        bestScore = currentScore;
      }
    }
    return bestScore > 0 ? best : null;
  }

  void _setSearchTextSilently(String value) {
    _searchController.removeListener(_applySearchFilter);
    _searchController.text = value;
    _searchController.selection =
        TextSelection.collapsed(offset: _searchController.text.length);
    _searchController.addListener(_applySearchFilter);
  }

  void _applySearchFilter() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _vehicleOptions = List<_VehicleOption>.from(_allVehicleOptions);
        _filteredOptions = List<_VehicleOption>.from(_allVehicleOptions);
        if (_selectedVehicle != null &&
            !_allVehicleOptions.any((o) => o.key == _selectedVehicle!.key)) {
          _selectedVehicle =
              _allVehicleOptions.isNotEmpty ? _allVehicleOptions.first : null;
        }
      });
      return;
    }

    final filtered = _allVehicleOptions.where((option) {
      final haystack = [
        option.label, option.vehicleNumber, option.driverName,
        option.cameraId, option.vin, option.licensePlateNumber,
        option.latestEventType,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    setState(() {
      _filteredOptions = filtered;
      if (filtered.isEmpty) {
        _selectedVehicle = null;
        return;
      }
      final hasValidSelection = _selectedVehicle != null &&
          filtered.any((item) => item.key == _selectedVehicle!.key);
      if (!hasValidSelection) {
        _selectedVehicle = filtered.first;
        _activeStream = null;
        _streamStatus = null;
      }
    });
  }

  void _startStreamExpiryCountdown() {
    if (_activeStream == null || _hasPlaybackStarted) return;

    _streamExpiryTimer?.cancel();
    _countdownTimer?.cancel();

    final expiryTime = DateTime.now().add(const Duration(seconds: 60));

    setState(() {
      _hasPlaybackStarted = true;
      _streamExpiryTime = expiryTime;
      _remainingSeconds = 60;
    });

    _streamExpiryTimer = Timer(const Duration(seconds: 60), () {
      if (!mounted) return;
      if (_isFullscreen && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _countdownTimer?.cancel();
      setState(() {
        _activeStream = null;
        _activeStreamVehicleKey = null;
        _streamStatus = null;
        _streamExpiryTime = null;
        _streamExpired = true;
        _remainingSeconds = 0;
        _hasPlaybackStarted = false;
      });
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final expiryTime = _streamExpiryTime;
      if (expiryTime == null) return;
      final secs = expiryTime.difference(DateTime.now()).inSeconds.clamp(0, 60);
      setState(() => _remainingSeconds = secs);
    });
  }

  Future<void> _startLivestream() async {
    final selected = _selectedVehicle;
    if (selected == null) return;

    _streamExpiryTimer?.cancel();
    _countdownTimer?.cancel();

    setState(() {
      _isStartingStream = true;
      _streamStatus = null;
      _activeStream = null;
      _streamExpired = false;
      _streamExpiryTime = null;
      _hasPlaybackStarted = false;
      _remainingSeconds = 0;
    });

    try {
      final payload = await LivestreamApi.createHlsStream(
        cameraPositions: const [0, 1],
        vehicle: {
          if (selected.vin.isNotEmpty) 'vin': selected.vin,
          if (selected.vehicleNumber.isNotEmpty) 'vehicleNumber': selected.vehicleNumber,
          if (selected.licensePlateNumber.isNotEmpty)
            'licensePlateNumber': selected.licensePlateNumber,
        },
        cameraId: selected.cameraId,
      );

      final data =
          (payload['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final urls =
          (data['liveStreamingHlsUrls'] as List<dynamic>? ?? <dynamic>[])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

      final playable = urls.firstWhere(
        (item) => _text(item['url']).isNotEmpty,
        orElse: () => <String, dynamic>{},
      );

      if (playable.isEmpty) {
        final message = urls
            .map((item) => _text(item['errorMessage']))
            .firstWhere((v) => v.isNotEmpty, orElse: () => 'Livestream unavailable.');
        throw Exception(message);
      }

      final hlsUrl = _text(playable['url']);

      setState(() {
        _activeStream = MediaItem(
          id: selected.eventId,
          type: 'video',
          title: '${selected.label} Livestream',
          url: hlsUrl,
          thumbnailUrl: null,
          mimeType: 'application/x-mpegURL',
          source: 'livestream',
        );
        _activeStreamVehicleKey = selected.key;
        _streamStatus = 'Live stream ready';
        _streamExpiryTime = null;
        _streamExpired = false;
        _remainingSeconds = 60;
        _hasPlaybackStarted = false;
      });
    } catch (error) {
      final msg = error.toString().replaceFirst('Exception: ', '');
      _countdownTimer?.cancel();
      setState(() {
        _activeStream = null;
        _activeStreamVehicleKey = null;
        _streamStatus = msg;
        _streamExpiryTime = null;
        _streamExpired = false;
        _remainingSeconds = 0;
        _hasPlaybackStarted = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isStartingStream = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Livestream')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadVehicles, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_vehicleOptions.isEmpty) {
      return const Center(child: Text('No vehicles available for livestream.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        // Text('Select a vehicle', style: Theme.of(context).textTheme.titleLarge),
        // const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search vehicle, driver, VIN, or camera',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () => _searchController.clear(),
                    icon: const Icon(Icons.close),
                  ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _filteredOptions.any((item) => item.key == _selectedVehicle?.key)
              ? _selectedVehicle?.key
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Vehicle',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          items: _filteredOptions
              .map((option) => DropdownMenuItem<String>(
                    value: option.key,
                    child: Text(
                      '${option.label} • ${option.driverName.isEmpty ? 'No driver' : option.driverName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            final match = _allVehicleOptions.firstWhere(
              (item) => item.key == value,
              orElse: () => _vehicleOptions.firstWhere((item) => item.key == value),
            );
            setState(() {
              _selectedVehicle = match;
              _activeStream = null;
              _streamStatus = null;
              _streamExpired = false;
              _streamExpiryTime = null;
            });
          },
        ),
        const SizedBox(height: 12),
        if (_selectedVehicle != null)
          _VehicleDetailsCard(vehicle: _selectedVehicle!),
        const SizedBox(height: 12),
        _buildPlayerSection(),
      ],
    );
  }

  Widget _buildPlayerSection() {
    final selected = _selectedVehicle;
    if (selected == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: vehicle • Live Stream
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(Icons.live_tv_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${selected.label} • Live Stream',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Video or idle placeholder
          if (_activeStream != null) ...[
            VideoPlayerCard(
              media: _activeStream!,
              isLivestream: true,
              onFullscreenChanged: (isFs) => setState(() => _isFullscreen = isFs),
              onPlaybackStarted: _startStreamExpiryCountdown,
            ),
            if (_activeStream != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: _hasPlaybackStarted && _remainingSeconds < 15
                          ? Colors.red.shade600
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _hasPlaybackStarted
                          ? (_remainingSeconds > 0
                              ? 'Stream expires in ${_remainingSeconds}s'
                              : 'Expiring...')
                          : 'Timer starts when playback begins',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _hasPlaybackStarted && _remainingSeconds < 15
                            ? Colors.red.shade600
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _streamExpired
                      ? const [Color(0xFFF1F0FB), Color(0xFFE7E5FA)]
                      : const [Color(0xFFF4F5F8), Color(0xFFE8EAF0)],
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _streamExpired
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                          : Colors.white.withOpacity(0.72),
                    ),
                    child: Icon(
                      _streamExpired
                          ? Icons.replay_circle_filled
                          : Icons.live_tv_rounded,
                      size: 42,
                      color: _streamExpired
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _streamExpired ? 'Stream ended' : 'Ready to stream',
                    style: TextStyle(
                      color: Colors.grey.shade900,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _streamExpired
                        ? 'Request another 60-second window to continue watching.'
                        : 'Tap "Play livestream" to start a 60-second HLS stream for ${selected.label}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

          // CTA + status
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_activeStream == null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: _isStartingStream || selected.cameraId.isEmpty
                        ? null
                        : _startLivestream,
                    icon: _isStartingStream
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _streamExpired ? Icons.replay : Icons.live_tv,
                          ),
                    label: Text(
                      _isStartingStream
                          ? 'Starting stream...'
                          : _streamExpired
                              ? 'Request another minute'
                              : 'Play livestream',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                if (selected.cameraId.isEmpty && !_isStartingStream) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'No camera ID available for this vehicle.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                // Error status
                if (_streamStatus != null &&
                    _activeStream == null &&
                    !_streamExpired) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _streamStatus!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Success status
                if (_streamStatus != null && _activeStream != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 15, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text(
                        _streamStatus!,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _text(dynamic value) => (value ?? '').toString().trim();
  static String _normalize(String? value) => (value ?? '').trim().toLowerCase();

  static String _pickFirstNonEmpty(List<String?> values) {
    for (final v in values) {
      final t = (v ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  static List<_VehicleOption> _buildOptions(List<Map<String, dynamic>> vehicles) {
    return vehicles.map((v) {
      return _VehicleOption(
        key: v['vehicleNumber'] ?? v['vin'] ?? v['licensePlateNumber'] ?? '',
        label: v['vehicleNumber'] ?? v['vin'] ?? 'Unknown',
        event: {},
        vehicleNumber: (v['vehicleNumber'] ?? '').toString(),
        vin: (v['vin'] ?? '').toString(),
        licensePlateNumber: (v['licensePlateNumber'] ?? '').toString(),
        driverName: (v['driverName'] ?? '').toString(),
        driverId: (v['driverId'] ?? '').toString(),
        cameraId: (v['cameraId'] ?? '').toString(),
        latestEventType: (v['latestEventType'] ?? '').toString(),
        latestSeverity: (v['latestSeverity'] ?? '').toString(),
        latestStatus: '',
        latestTimestamp: DateTime.fromMillisecondsSinceEpoch(
          v['latestTimestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        ),
        latestLocation: (v['latestLocation'] ?? '').toString(),
      );
    }).toList();
  }

  static String _formatLocation(Map<dynamic, dynamic> location) {
    final parts = <String>[
      _text(location['address']),
      _text(location['city']),
      _text(location['state']),
    ].where((v) => v.isNotEmpty).toList();
    return parts.join(', ');
  }
}

// ---------------------------------------------------------------------------
// _VehicleDetailsCard
// ---------------------------------------------------------------------------
class _VehicleDetailsCard extends StatelessWidget {
  const _VehicleDetailsCard({required this.vehicle});
  final _VehicleOption vehicle;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                _SeverityChip(label: vehicle.latestSeverity),
              ],
            ),
            const SizedBox(height: 10),
            _CompactDetailGrid(vehicle: vehicle, formatter: formatter),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CompactDetailGrid
// ---------------------------------------------------------------------------
class _CompactDetailGrid extends StatelessWidget {
  const _CompactDetailGrid({required this.vehicle, required this.formatter});
  final _VehicleOption vehicle;
  final DateFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _DetailTile(label: 'Driver', value: vehicle.driverName.isEmpty ? 'Unassigned' : vehicle.driverName)),
          const SizedBox(width: 12),
          Expanded(child: _DetailTile(label: 'Camera ID', value: vehicle.cameraId.isEmpty ? 'Unavailable' : vehicle.cameraId)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _DetailTile(label: 'VIN', value: vehicle.vin.isEmpty ? 'Unavailable' : vehicle.vin)),
          const SizedBox(width: 12),
          Expanded(child: _DetailTile(label: 'Status', value: vehicle.latestStatus.isEmpty ? 'Unavailable' : vehicle.latestStatus)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _DetailTile(label: 'Latest event', value: vehicle.latestEventType.isEmpty ? 'Unavailable' : vehicle.latestEventType)),
          const SizedBox(width: 12),
          Expanded(child: _DetailTile(label: 'Time', value: formatter.format(vehicle.latestTimestamp))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _DetailTile(label: 'License plate', value: vehicle.licensePlateNumber.isEmpty ? 'Unavailable' : vehicle.licensePlateNumber)),
          const SizedBox(width: 12),
          Expanded(child: _DetailTile(label: 'Location', value: vehicle.latestLocation.isEmpty ? 'Unavailable' : vehicle.latestLocation, maxLines: 2)),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _DetailTile
// ---------------------------------------------------------------------------
class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.label, required this.value, this.maxLines = 2});
  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 3),
        Text(value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600, height: 1.25)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SeverityChip
// ---------------------------------------------------------------------------
class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final Color color;
    if (normalized.contains('alert')) {
      color = Colors.red;
    } else if (normalized.contains('warn')) {
      color = Colors.orange;
    } else if (normalized.contains('driver')) {
      color = Colors.green;
    } else {
      color = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withOpacity(0.12),
      ),
      child: Text(
        label.isEmpty ? 'UNKNOWN' : label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _VehicleOption
// ---------------------------------------------------------------------------
class _VehicleOption {
  const _VehicleOption({
    required this.key,
    required this.label,
    required this.event,
    required this.vehicleNumber,
    required this.vin,
    required this.licensePlateNumber,
    required this.driverName,
    required this.driverId,
    required this.cameraId,
    required this.latestEventType,
    required this.latestSeverity,
    required this.latestStatus,
    required this.latestTimestamp,
    required this.latestLocation,
  });

  final String key;
  final String label;
  final Map<String, dynamic> event;
  final String vehicleNumber;
  final String vin;
  final String licensePlateNumber;
  final String driverName;
  final String driverId;
  final String cameraId;
  final String latestEventType;
  final String latestSeverity;
  final String latestStatus;
  final DateTime latestTimestamp;
  final String latestLocation;

  int get eventId {
    final id = event['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse(id?.toString() ?? '') ?? 0;
  }
}