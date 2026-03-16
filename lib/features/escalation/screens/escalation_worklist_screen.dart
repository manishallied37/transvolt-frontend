import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/escalation_api.dart';

class EscalationWorklistScreen extends StatefulWidget {
  const EscalationWorklistScreen({super.key});

  @override
  State<EscalationWorklistScreen> createState() =>
      _EscalationWorklistScreenState();
}

class _EscalationWorklistScreenState extends State<EscalationWorklistScreen> {
  final EscalationApi api = EscalationApi();

  List _all = [];
  List _filtered = [];
  bool loading = true;

  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  String? _selectedType;
  String? _selectedDateRange;

  final List<String> _statuses = [
    'ESCALATED_TO_CC',
    'UNDER_REVIEW',
    'ESCALATED_TO_AUTHORITY',
    'CLOSED',
    'REJECTED',
  ];
  final List<String> _types = [
    'Fatigue / drowsiness risk',
    'Unsafe driving behavior',
    'Speed violation',
    'Driver distraction',
    'Traffic rule violation',
    'Safety compliance issue',
    'Potential accident risk',
    'Policy breach',
  ];
  final List<String> _dateRanges = ['Today', 'Last 7 days', 'Last 30 days'];

  @override
  void initState() {
    super.initState();
    loadEscalations();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadEscalations() async {
    try {
      final response = await api.getEscalations();
      setState(() {
        _all = response["escalations"] ?? [];
        _filtered = List.from(_all);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load escalations: $e")),
        );
      }
    }
  }

  void _applyFilters() {
    final q = _searchController.text.toLowerCase();
    final now = DateTime.now();

    setState(() {
      _filtered = _all.where((e) {
        // Search
        final matchQ =
            q.isEmpty ||
            (e['driver_name'] ?? '').toLowerCase().contains(q) ||
            (e['vehicle_id'] ?? '').toLowerCase().contains(q) ||
            (e['escalation_type'] ?? '').toLowerCase().contains(q) ||
            (e['event_sub_type'] ?? '').toLowerCase().contains(q) ||
            (e['city'] ?? '').toLowerCase().contains(q);

        // Status
        final matchStatus =
            _selectedStatus == null || e['status'] == _selectedStatus;

        // Type
        final matchType =
            _selectedType == null || e['escalation_type'] == _selectedType;

        // Date
        bool matchDate = true;
        if (_selectedDateRange != null) {
          final raw = e['created_at'] as String?;
          final date = raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
          if (date != null) {
            final diff = now.difference(date).inDays;
            if (_selectedDateRange == 'Today') {
              matchDate = diff == 0;
            } else if (_selectedDateRange == 'Last 7 days') {
              matchDate = diff <= 7;
            } else if (_selectedDateRange == 'Last 30 days') {
              matchDate = diff <= 30;
            }
          }
        }

        return matchQ && matchStatus && matchType && matchDate;
      }).toList();
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatus = null;
      _selectedType = null;
      _selectedDateRange = null;
    });
    _applyFilters();
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'ESCALATED_TO_CC':
        return const Color(0xFF534AB7);
      case 'RESOLVED':
        return const Color(0xFF3B6D11);
      case 'PENDING':
        return const Color(0xFF854F0B);
      case 'CLOSED':
        return const Color(0xFF5F5E5A);
      default:
        return Colors.grey;
    }
  }

  Color _statusBg(String? status) {
    switch (status) {
      case 'ESCALATED_TO_CC':
        return const Color(0xFFEEEDFE);
      case 'RESOLVED':
        return const Color(0xFFEAF3DE);
      case 'PENDING':
        return const Color(0xFFFAEEDA);
      case 'CLOSED':
        return const Color(0xFFF1EFE8);
      default:
        return Colors.grey.shade100;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'ESCALATED_TO_CC':
        return 'Escalated to CC';
      case 'UNDER_REVIEW':
        return 'Under review';
      case 'ESCALATED_TO_AUTHORITY':
        return 'Escalated to Authority';
      case 'CLOSED':
        return 'Closed';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status ?? '-';
    }
  }

  Color _severityColor(int level) {
    if (level >= 3) return const Color(0xFFA32D2D);
    if (level == 2) return const Color(0xFF854F0B);
    return const Color(0xFF3B6D11);
  }

  String _severityLabel(int level) {
    if (level >= 3) return 'High';
    if (level == 2) return 'Medium';
    return 'Low';
  }

  String _formatDate(String? raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw)?.toLocal();
    return dt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(dt) : '-';
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        _selectedStatus != null ||
        _selectedType != null ||
        _selectedDateRange != null ||
        _searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Escalation worklist",
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
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Toolbar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by driver, vehicle, type...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Filter chips row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: _selectedStatus != null
                                  ? _statusLabel(_selectedStatus)
                                  : 'Status',
                              isActive: _selectedStatus != null,
                              onTap: () => _showBottomSheet(
                                context,
                                'Filter by status',
                                _statuses.map(_statusLabel).toList(),
                                (v) => setState(() {
                                  _selectedStatus =
                                      _statuses[_statuses
                                          .map(_statusLabel)
                                          .toList()
                                          .indexOf(v)];
                                  _applyFilters();
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: _selectedType ?? 'Escalation type',
                              isActive: _selectedType != null,
                              onTap: () => _showBottomSheet(
                                context,
                                'Filter by type',
                                _types,
                                (v) => setState(() {
                                  _selectedType = v;
                                  _applyFilters();
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: _selectedDateRange ?? 'Date range',
                              isActive: _selectedDateRange != null,
                              onTap: () => _showBottomSheet(
                                context,
                                'Filter by date',
                                _dateRanges,
                                (v) => setState(() {
                                  _selectedDateRange = v;
                                  _applyFilters();
                                }),
                              ),
                            ),
                            if (hasActiveFilters) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _clearFilters,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFCEBEB),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "Clear",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFA32D2D),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Count bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _filtered.length == _all.length
                          ? '${_all.length} escalations'
                          : '${_filtered.length} of ${_all.length} escalations',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                ),

                // List or empty state
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) =>
                              _buildCard(_filtered[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCard(Map e) {
    final sevLevel = (e['severity_level'] as num?)?.toInt() ?? 1;
    final speed = double.tryParse(e['max_vehicle_speed'] ?? '') ?? 0;
    final gForce = double.tryParse(e['max_g_force'] ?? '') ?? 0;
    final conf = double.tryParse(e['confidence'] ?? '') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e['escalation_type'] ?? '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${e['event_sub_type'] ?? '-'} · Event #${e['event_id'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusPill(e['status']),
                    const SizedBox(height: 4),
                    _severityPill(sevLevel),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5, color: Colors.black12),
            const SizedBox(height: 12),

            // Meta grid
            Row(
              children: [
                _metaItem('Driver', e['driver_name'] ?? '-'),
                _metaItem('Vehicle', e['vehicle_id'] ?? '-'),
                _metaItem('City', e['city'] ?? '-'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metaItem('Max speed', '${speed.toStringAsFixed(0)} km/h'),
                _metaItem('G-force', gForce.toStringAsFixed(2)),
                _metaItem('Confidence', '${(conf * 100).toStringAsFixed(0)}%'),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5, color: Colors.black12),
            const SizedBox(height: 10),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(e['created_at']),
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await api.updateEscalationStatus(e['id'], 'UNDER_REVIEW');
                      // Update locally so UI reflects immediately without refetch
                      setState(() {
                        final idx = _all.indexWhere(
                          (item) => item['id'] == e['id'],
                        );
                        if (idx != -1) {
                          _all[idx] = {..._all[idx], 'status': 'UNDER_REVIEW'};
                        }
                        final fidx = _filtered.indexWhere(
                          (item) => item['id'] == e['id'],
                        );
                        if (fidx != -1) {
                          _filtered[fidx] = {
                            ..._filtered[fidx],
                            'status': 'UNDER_REVIEW',
                          };
                        }
                      });
                    } catch (err) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to update status: $err"),
                          ),
                        );
                        return;
                      }
                    }
                    if (mounted) {
                      Navigator.pushNamed(
                        context,
                        '/escalation-review',
                        arguments: e['id'],
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    backgroundColor: const Color(0xFFF1EFE8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Review',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String? status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusBg(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _statusColor(status),
        ),
      ),
    );
  }

  Widget _severityPill(int level) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _severityColor(level),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          _severityLabel(level),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _severityColor(level),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEEEDFE) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF534AB7) : Colors.black12,
            width: isActive ? 1 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isActive ? const Color(0xFF3C3489) : Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive ? const Color(0xFF3C3489) : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF1EFE8),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              color: Colors.black38,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "No escalations found",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Try adjusting your filters or search query",
            style: TextStyle(fontSize: 13, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  void _showBottomSheet(
    BuildContext context,
    String title,
    List<String> options,
    void Function(String) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            ...options.map(
              (opt) => ListTile(
                dense: true,
                title: Text(opt, style: const TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  onSelect(opt);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
