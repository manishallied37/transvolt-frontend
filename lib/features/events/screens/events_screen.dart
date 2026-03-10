import 'package:flutter/material.dart';
import '../services/events_api.dart';
import 'event_details_screen.dart';

/// Simple model extractors (no full models to keep it concise)
String _safeStr(dynamic v) => (v ?? '').toString();

/// Map severityDescription -> color theme for the card
// Color _severityCardColor(String? sev) {
//   final s = (sev ?? '')
//       .trim()
//       .toLowerCase()
//       .replaceAll('-', '')
//       .replaceAll(' ', '');

//   if (s == 'alert') return Colors.red.shade50;
//   if (s == 'warn') return Colors.amber.shade50;
//   if (s == 'driverstar' || s == 'driver-star' || s == 'driver_star')
//     return Colors.green.shade50;
//   if (s == 'neutral') return Colors.blue;

//   return Colors.grey.shade100;
// }

Color _severityAccent(String? sev) {
  final s = (sev ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('-', '')
      .replaceAll(' ', '');

  if (s == 'alert') return Colors.red;
  if (s == 'warn') return Colors.amber.shade800;
  if (s == 'driverstar' || s == 'driver-star' || s == 'driver_star')
  {
    return Colors.green.shade700;
  }
  if (s == 'neutral') return Colors.blue;

  return Colors.grey;
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  DateTime? _startDateTime;
  DateTime? _endDateTime;

  // Raw data and derived state
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _visible = [];

  // Pagination
  final int _pageSize = 50;
  int _page = 1;

  final ScrollController _scrollController = ScrollController();

  // Search & filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedSeverity;
  String? _selectedType;
  String? _selectedCity;

  // Dropdown data
  List<String> _allSeverities = [];
  List<String> _allTypes = [];
  List<String> _allCities = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // final now = DateTime.now();

    _startDateTime = null;
    _endDateTime = null;

    _fetchInitial();

    // _scrollController.addListener(() {
    //   if (_scrollController.position.pixels >=
    //       _scrollController.position.maxScrollExtent - 100) {
    //     _loadMore();
    //   }
    // });
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null) return null;

    if (!mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );

    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _fetchInitial() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Fetch a chunk
      final resp = await EventApi.getAlerts(count: 100);
      final List<dynamic> data = resp['data'] ?? [];

      _all = data
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Build dropdown options
      _allSeverities = _uniqueStrings(
        _all.map((e) => _safeStr((e['details'] ?? {})['severityDescription'])),
      );

      _allTypes = _uniqueStrings(
        _all.map((e) => _safeStr((e['details'] ?? {})['typeDescription'])),
      );

      _allCities = _uniqueStrings(
        _all.map(
          (e) => _safeStr(((e['details'] ?? {})['location'] ?? {})['city']),
        ),
      );

      _applyAllFilters(resetPage: true);
    } catch (e) {
      setState(() {
        _error = "Failed to load events: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  List<String> _uniqueStrings(Iterable<String> it) {
    final s = <String>{};

    for (final v in it) {
      if (v.trim().isNotEmpty) s.add(v);
    }

    final list = s.toList()..sort();
    return list;
  }

  void _applyAllFilters({bool resetPage = false}) {
    // 1) Start from all
    List<Map<String, dynamic>> items = List.from(_all);

    // 2) Search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();

      items = items.where((e) {
        final driver = (e['driver'] as Map?) ?? {};
        final first = _safeStr(driver['firstName']);
        final last = _safeStr(driver['lastName']);
        final fullName = "$first $last".toLowerCase();
        final did = _safeStr(driver['driverId']).toLowerCase();

        final details = (e['details'] as Map?) ?? {};
        final typeDesc = _safeStr(details['typeDescription']).toLowerCase();
        final severityDesc = _safeStr(
          details['severityDescription'],
        ).toLowerCase();

        final city = _safeStr(
          (details['location'] ?? {})['city'],
        ).toLowerCase();

        final vehicleNum = _safeStr(
          (e['vehicle'] ?? {})['vehicleNumber'],
        ).toLowerCase();

        return fullName.contains(q) ||
            first.toLowerCase().contains(q) ||
            last.toLowerCase().contains(q) ||
            did.contains(q) ||
            typeDesc.contains(q) ||
            severityDesc.contains(q) ||
            city.contains(q) ||
            vehicleNum.contains(q);
      }).toList();
    }

    if (_startDateTime != null || _endDateTime != null) {
      items = items.where((e) {
        final ts = e['timestamp'];
        if (ts == null) return false;

        final dt = DateTime.fromMillisecondsSinceEpoch((ts as num).toInt());

        if (_startDateTime != null && dt.isBefore(_startDateTime!)) {
          return false;
        }
        if (_endDateTime != null && dt.isAfter(_endDateTime!)) return false;
        return true;
      }).toList();
    }

    // 3) Severity
    if (_selectedSeverity != null && _selectedSeverity!.isNotEmpty) {
      items = items.where((e) {
        final details = (e['details'] as Map?) ?? {};
        return _safeStr(details['severityDescription']) == _selectedSeverity;
      }).toList();
    }

    // 4) Type
    if (_selectedType != null && _selectedType!.isNotEmpty) {
      items = items.where((e) {
        final details = (e['details'] as Map?) ?? {};
        return _safeStr(details['typeDescription']) == _selectedType;
      }).toList();
    }

    // 5) City
    if (_selectedCity != null && _selectedCity!.isNotEmpty) {
      items = items.where((e) {
        final details = (e['details'] as Map?) ?? {};
        final loc = (details['location'] as Map?) ?? {};
        return _safeStr(loc['city']) == _selectedCity;
      }).toList();
    }

    _filtered = items;

    if (resetPage) _page = 1;

    _rebuildVisible();
  }

  void _rebuildVisible() {
    final end = (_page * _pageSize).clamp(0, _filtered.length);

    setState(() {
      _visible = _filtered.take(end).toList();
    });
  }

  void _loadMore() {
    if (_visible.length >= _filtered.length) return;

    _page += 1;
    final end = (_page * _pageSize).clamp(0, _filtered.length);

    setState(() {
      _visible = _filtered.take(end).toList();
    });
  }

  Future<void> _refresh() async {
    await _fetchInitial();
  }

  void _onSearchPressed() {
    _searchQuery = _searchController.text;
    _applyAllFilters(resetPage: true);
  }

  void _openFilterDialog() async {
    DateTime? tempStart = _startDateTime;
    DateTime? tempEnd = _endDateTime;
    String? tempSeverity = _selectedSeverity;
    String? tempType = _selectedType;
    String? tempCity = _selectedCity;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StatefulBuilder(
              builder: (context, setLocalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Filters",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Severity
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Severity",
                        border: OutlineInputBorder(),
                      ),
                      initialValue: tempSeverity,
                      items: [
                        const DropdownMenuItem(value: null, child: Text("All")),
                        ..._allSeverities.map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        ),
                      ],
                      onChanged: (v) => setLocalState(() => tempSeverity = v),
                    ),

                    const SizedBox(height: 12),

                    // Type
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Type",
                        border: OutlineInputBorder(),
                      ),
                      initialValue: tempType,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text("All", overflow: TextOverflow.ellipsis),
                        ),
                        ..._allTypes.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (v) => setLocalState(() => tempType = v),
                    ),

                    const SizedBox(height: 12),

                    // City
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "City",
                        border: OutlineInputBorder(),
                      ),
                      initialValue: tempCity,
                      items: [
                        const DropdownMenuItem(value: null, child: Text("All")),
                        ..._allCities.map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        ),
                      ],
                      onChanged: (v) => setLocalState(() => tempCity = v),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final dt = await _pickDateTime(tempStart);
                              if (dt != null) {
                                setLocalState(() => tempStart = dt);
                              }
                            },
                            child: Text(
                              tempStart == null
                                  ? "From Date"
                                  : "From: ${tempStart!.toLocal()}".substring(
                                      0,
                                      16,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final dt = await _pickDateTime(tempEnd);
                              if (dt != null) {
                                setLocalState(() => tempEnd = dt);
                              }
                            },
                            child: Text(
                              tempEnd == null
                                  ? "To Date"
                                  : "To: ${tempEnd!.toLocal()}".substring(
                                      0,
                                      16,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: const Text("Clear"),
                          onPressed: () {
                            setLocalState(() {
                              tempSeverity = null;
                              tempType = null;
                              tempCity = null;
                              tempStart = null;
                              tempEnd = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          child: const Text("Apply"),
                          onPressed: () {
                            Navigator.of(context).pop();

                            setState(() {
                              _selectedSeverity = tempSeverity;
                              _selectedType = tempType;
                              _selectedCity = tempCity;

                              _startDateTime = tempStart;
                              _endDateTime = tempEnd;

                              _applyAllFilters(resetPage: true);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(dynamic ts) {
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch((ts as num).toInt());
      return "${dt.year}-${_two(dt.month)}-${_two(dt.day)} "
          "${_two(dt.hour)}:${_two(dt.minute)}";
    } catch (_) {
      return ts?.toString() ?? "-";
    }
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Events"),
        actions: [
          // IconButton(
          //   tooltip: "Refresh",
          //   icon: const Icon(Icons.refresh),
          //   onPressed: _refresh,
          // ),
        ],
      ),

      body: Column(
        children: [
          // Search + filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _onSearchPressed(),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        hintText: "Search driver, type, city, vehicle...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Search Button
                SizedBox(
                  height: 44,
                  width: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.center,
                    ),
                    onPressed: _onSearchPressed,
                    child: const Icon(Icons.search, size: 22),
                  ),
                ),
                const SizedBox(width: 8),

                // Filter Button
                SizedBox(
                  height: 44,
                  width: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.center,
                    ),
                    onPressed: _openFilterDialog,
                    child: const Icon(Icons.filter_alt, size: 22),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    )
                  : _visible.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 40),
                        Center(child: Text("No events found")),
                      ],
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      itemCount:
                          _visible.length +
                          (_visible.length < _filtered.length ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemBuilder: (context, index) {
                        // SHOW MORE BUTTON
                        if (index >= _visible.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: ElevatedButton(
                                onPressed: _loadMore,
                                child: const Text("Show More"),
                              ),
                            ),
                          );
                        }

                        final item = _visible[index];

                        final details = (item['details'] as Map?) ?? {};
                        final driver = (item['driver'] as Map?) ?? {};
                        final location = (details['location'] as Map?) ?? {};

                        final severityDesc = _safeStr(
                          details['severityDescription'],
                        );
                        final typeDesc = _safeStr(details['typeDescription']);

                        final driverName =
                            "${_safeStr(driver['firstName'])} ${_safeStr(driver['lastName'])}"
                                .trim();
                        final driverId = _safeStr(driver['driverId']);

                        final address = _safeStr(location['address']);
                        final city = _safeStr(location['city']);
                        final state = _safeStr(location['state']);

                        final ts = _formatTimestamp(item['timestamp']);

                        // final cardBg = _severityCardColor(severityDesc);
                        final accent = _severityAccent(severityDesc);

                        return InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EventDetailsScreen(item: item),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        typeDesc.isEmpty ? "-" : typeDesc,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: accent),
                                      ),
                                      child: Text(
                                        severityDesc.isEmpty
                                            ? "-"
                                            : severityDesc,
                                        style: TextStyle(
                                          color: accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        "$driverName (${driverId.isEmpty ? '-' : driverId})",
                                        style: theme.textTheme.bodyMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.place, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        "${address.isEmpty ? '-' : address}, "
                                        "${city.isEmpty ? '-' : city}, "
                                        "${state.isEmpty ? '-' : state}",
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 18),
                                    const SizedBox(width: 6),
                                    Text(ts, style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
