// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/features/media/screens/media_details_screen.dart';
import 'escalation_form_screen.dart';

import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;

/// Pass your event/item payload in [item].
class EventDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? item;
  const EventDetailsScreen({super.key, required this.item});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  // Map
  final fm.MapController _mapController = fm.MapController();
  List<ll.LatLng> _path = [];
  ll.LatLng? _start;
  ll.LatLng? _end;

  // Prefer to inject via --dart-define=MAPTILER_KEY=xxxx at build time
  static const String _mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: '',
  );

  @override
  void initState() {
    super.initState();
    _hydrateGps();
  }

  void _hydrateGps() {
    final item = widget.item ?? {};
    final List<dynamic>? gps = item['gpsData'] as List<dynamic>?;
    if (gps == null || gps.isEmpty) return;

    _path = gps
        .map(
          (e) => ll.LatLng(
            (e['latitude'] as num).toDouble(),
            (e['longitude'] as num).toDouble(),
          ),
        )
        .toList();

    _start = _path.first;
    _end = _path.last;
  }

  String _fmtTs(int? ms) {
    if (ms == null) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }

  Color _severityColor(num? sev) {
    switch (sev?.toInt()) {
      case 3:
        debugPrint('3 driverstar');
        return Colors.green;
      case 2:
        debugPrint('2 warn');
        return Colors.orange;

      case 1:
        debugPrint('1 alert');
        return Colors.red;
      default:
        debugPrint('neutral');
        return Colors.blue;
    }
  }

  // void main() {
  //   String name = "Flutter";
  //   print("Hello, $name!"); // Prints to the debug console
  // }

  // Choose a production-friendly tile source first; fall back to OSM if no key.
  String get _tileUrlTemplate {
    if (_mapTilerKey.isNotEmpty) {
      // MapTiler allows web & mobile with API key
      return 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=$_mapTilerKey';
    }
    // Conservative OSM endpoint (single host). For light/dev usage only.
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Event Details")),
        body: const Center(child: Text("No data")),
      );
    }

    final id = item['id'];
    final status = item['status'] ?? '—';

    final details = (item['details'] ?? {}) as Map<String, dynamic>;
    final String typeDescription = details['typeDescription'] ?? '';
    final String eventDescription = details['subTypeDescription'] ?? '';
    final severity = details['severity'] as num?;
    final severityDesc = (details['severityDescription'] ?? '—').toString();

    final vehicle = (item['vehicle'] ?? {}) as Map<String, dynamic>;
    final vehicleNo = (vehicle['vehicleNumber'] ?? '—').toString();
    final vin = (vehicle['vin'] ?? '—').toString();

    final driver = (item['driver'] ?? {}) as Map<String, dynamic>;
    final driverName =
        "${(driver['firstName'] ?? '').toString().trim()} ${(driver['lastName'] ?? '').toString().trim()}"
            .trim();
    // final driverId = (driver['driverId'] ?? '—').toString();

    final loc = (details['location'] ?? {}) as Map<String, dynamic>;

    final depot = [
      loc['city'],
      loc['state'],
    ].where((e) => (e ?? '').toString().isNotEmpty).join(', ');
    final ts = item['timestamp'] as int?;

    final addressParts = [
      loc['address'],
      loc['city'],
      loc['state'],
      loc['postalCode'],
      loc['country'],
    ].where((e) => (e ?? '').toString().isNotEmpty).toList();
    final address = addressParts.isEmpty ? '—' : addressParts.join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text("Event Details")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ===== Top: 3 neatly aligned cards =====
                Column(
                  children: [
                    /// ===== FIRST CARD (FULL WIDTH ALWAYS) =====
                    SizedBox(
                      width: double.infinity,
                      child: _SectionCard(
                        title: typeDescription,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// LEFT DETAILS
                              Expanded(
                                child: MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                    textScaler: const TextScaler.linear(1.0),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _kvRow('Event ID', id?.toString() ?? '—'),
                                      const SizedBox(height: 8),
                                      _kvRow('Vehicle No', vehicleNo),
                                      const SizedBox(height: 8),
                                      _kvRow('VIN', vin),
                                      const SizedBox(height: 8),
                                      _kvRow(
                                        'Driver',
                                        (driverName.isEmpty ? '—' : '$driverName '),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 0),

                              /// RIGHT IMAGE
                              Transform.translate(
                                offset: const Offset(5, -35),
                                child: GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        backgroundColor: Colors.transparent,
                                        child: InteractiveViewer(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              'https://i.pravatar.cc/150',
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: FittedBox(
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey,
                                          width: 2,
                                        ),
                                      ),
                                      child: const CircleAvatar(
                                        backgroundImage: NetworkImage(
                                          'https://i.pravatar.cc/150',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// ===== SECOND ROW =====
                    isWide
                        ? Row(
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    _SectionCard(
                                      title: 'Location & Severity',
                                      children: [
                                        _kvRow(
                                          'Depot',
                                          depot.isEmpty ? '—' : depot,
                                        ),
                                        const SizedBox(height: 8),
                                        _kvRow(
                                          'EventDescription',
                                          eventDescription.isEmpty
                                              ? '—'
                                              : eventDescription,
                                        ),
                                      ],
                                    ),
                                    Positioned(
                                      top: 12,
                                      right: 20,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _severityColor(
                                            severity,
                                          ).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: _severityColor(severity),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          severityDesc,
                                          style: TextStyle(
                                            color: _severityColor(severity),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 16),

                              Expanded(
                                child: _SectionCard(
                                  title: 'Status & Timing',
                                  children: [
                                    _kvRow('Status', status.toString()),
                                    const SizedBox(height: 8),
                                    _kvRow('Time', _fmtTs(ts)),
                                    const SizedBox(height: 8),
                                    _kvRow('Address', address, maxLines: 2),
                                  ],
                                ),
                              ),
                            ],
                          )
                        /// MOBILE (STACKED)
                        : Column(
                            children: [
                              Stack(
                                children: [
                                  _SectionCard(
                                    title: 'Location & Severity',
                                    children: [
                                      _kvRow(
                                        'Depot',
                                        depot.isEmpty ? '—' : depot,
                                      ),
                                      const SizedBox(height: 8),
                                      _kvRow(
                                        'EventDescription',
                                        eventDescription.isEmpty
                                            ? '—'
                                            : eventDescription,
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 20,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _severityColor(
                                          severity,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: _severityColor(severity),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        severityDesc,
                                        style: TextStyle(
                                          color: _severityColor(severity),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              _SectionCard(
                                title: 'Status & Timing',
                                children: [
                                  _kvRow('Status', status.toString()),
                                  const SizedBox(height: 8),
                                  _kvRow('Time', _fmtTs(ts)),
                                  const SizedBox(height: 8),
                                  _kvRow('Address', address, maxLines: 2),
                                ],
                              ),
                            ],
                          ),
                  ],
                ),

                const SizedBox(height: 16),

                // ===== Map + Right Panel =====
                if (isWide)
                  // WIDE: Row is fine. Use Expanded only for width, bound the height via SizedBox.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 320,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildMap(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 140,
                        child: _RightPanel(
                          mapTilerKey: _mapTilerKey,
                          item: item,
                        ),
                      ),
                    ],
                  )
                else
                  // NARROW: Column inside a scroll view -> do NOT use Expanded here.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 320,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildMap(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RightPanel(mapTilerKey: _mapTilerKey, item: item),
                    ],
                  ),

                // ===== Raw payload hidden by default =====
                // if (kDebugMode && false) ...[
                //   const SizedBox(height: 16),
                //   ExpansionTile(
                //     initiallyExpanded: false,
                //     title: const Text('Raw payload (debug)'),
                //     children: [
                //       Container(
                //         width: double.infinity,
                //         padding: const EdgeInsets.all(12),
                //         decoration: BoxDecoration(
                //           color: Colors.grey.shade50,
                //           borderRadius: BorderRadius.circular(8),
                //           border: Border.all(color: Colors.grey.shade300),
                //         ),
                //         child: SelectableText(
                //           _prettyJson(widget.item!),
                //           style: const TextStyle(
                //             fontFamily: 'monospace',
                //             fontSize: 12.5,
                //           ),
                //         ),
                //       ),
                //       const SizedBox(height: 8),
                //     ],
                //   ),
                // ],
              ],
            ),
          );
        },
      ),
    );
  }

  // double _cardWidth(bool isWide, double maxWidth) {
  //   if (!isWide) return double.infinity;
  //   // 3 columns on wide screens
  //   final totalSpacing = 16 * 2; // spacing between 3 cards in the Wrap
  //   return (maxWidth - totalSpacing - 32 /*page padding approx*/ ) / 3;
  // }

  Widget _buildMap() {
    if (_end == null) {
      return const Center(child: Text('No GPS data'));
    }
    final points = _path
        .map((p) => ll.LatLng(p.latitude, p.longitude))
        .toList();

    return fm.FlutterMap(
      mapController: _mapController,
      options: fm.MapOptions(
        initialCenter: points.last,
        initialZoom: 14,
        onMapReady: _fitToPath,
      ),
      children: [
        fm.TileLayer(
          urlTemplate: _tileUrlTemplate,
          // Use your real package name here (important for native UA)
          userAgentPackageName: 'com.yourcompany.yourapp',
        ),

        if (points.isNotEmpty)
          fm.PolylineLayer(
            polylines: [
              fm.Polyline(points: points, color: Colors.blue, strokeWidth: 4),
            ],
          ),
        fm.MarkerLayer(
          markers: [
            if (_start != null)
              fm.Marker(
                point: ll.LatLng(_start!.latitude, _start!.longitude),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 36,
                ),
              ),
            fm.Marker(
              point: ll.LatLng(_end!.latitude, _end!.longitude),
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Colors.red, size: 36),
            ),
          ],
        ),
      ],
    );
  }

  void _fitToPath() {
    if (_path.isEmpty) return;
    try {
      final bounds = fm.LatLngBounds.fromPoints(_path);
      final camera = fm.CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      );
      _mapController.fitCamera(camera);
    } catch (_) {
      // ignore
    }
  }

  // void _onEscalate(Map<String, dynamic> item) {
  //   Navigator.of(context).push(
  //     MaterialPageRoute(
  //       builder: (_) => EscalationFormScreen(escalationDetailsArray: item),
  //     ),
  //   );
  // }

  // String _prettyJson(Map<String, dynamic> json) => _reencodePretty(json);
}

/// ===== Right Panel (thumbnail + escalate + attribution) =====
class _RightPanel extends StatelessWidget {
  final String mapTilerKey;
  final Map<String, dynamic>? item;

  const _RightPanel({required this.mapTilerKey, required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              if (item == null) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MediaDetailsScreen(mediaDetailsArray: item!),
                ),
              );
            },
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text("View Media"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue, width: 1.5),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              if (item == null) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EscalationFormScreen(escalationDetailsArray: item!),
                ),
              );
            },
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Escalate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Text(
        //   mapTilerKey.isNotEmpty
        //       ? '© MapTiler • © OpenStreetMap'
        //       : '© OpenStreetMap contributors',
        //   style: TextStyle(
        //     fontSize: 11,
        //     color: Colors.grey.shade600,
        //   ),
        //   textAlign: TextAlign.center,
        // ),
      ],
    );
  }
}

/// ===== Reusable Section Card =====
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// ===== Key-Value Row =====
Widget _kvRow(String k, String v, {Widget? trailing, int maxLines = 1}) {
  final keyStyle = TextStyle(
    color: Colors.grey.shade700,
    fontWeight: FontWeight.w600,
  );
  final valStyle = const TextStyle(fontWeight: FontWeight.w500);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 120, child: Text(k, style: keyStyle)),
      const SizedBox(width: 10),
      Expanded(
        child:
            trailing ??
            Text(
              v,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: valStyle,
            ),
      ),
    ],
  );
}

/// ===== Simple pretty print (kept for optional debug) =====
// String _reencodePretty(Map<String, dynamic> map) => _pretty(map, 0);
// String _indent(int n) => '  ' * n;
// String _pretty(dynamic v, int level) {
//   if (v is Map) {
//     final entries = v.entries
//         .map(
//           (e) =>
//               '${_indent(level + 1)}"${e.key}": ${_pretty(e.value, level + 1)}',
//         )
//         .join(',\n');
//     return '{\n$entries\n${_indent(level)}}';
//   } else if (v is List) {
//     final items = v
//         .map((e) => '${_indent(level + 1)}${_pretty(e, level + 1)}')
//         .join(',\n');
//     return '[\n$items\n${_indent(level)}]';
//   } else if (v is String) {
//     return '"$v"';
//   } else {
//     return v?.toString() ?? 'null';
//   }
// }
