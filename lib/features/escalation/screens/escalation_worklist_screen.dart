import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/escalation_provider.dart';
import '../../../../shared/widgets/async_value_widget.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../services/escalation_api.dart';

class EscalationWorklistScreen extends ConsumerStatefulWidget {
  const EscalationWorklistScreen({super.key});

  @override
  ConsumerState<EscalationWorklistScreen> createState() =>
      _EscalationWorklistScreenState();
}

class _EscalationWorklistScreenState
    extends ConsumerState<EscalationWorklistScreen> {
  final TextEditingController _searchController = TextEditingController();

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────

  Color _statusColor(String? status) {
    switch (status) {
      case 'ESCALATED_TO_CC':
        return const Color(0xFF534AB7);
      case 'UNDER_REVIEW':
        return const Color(0xFF854F0B);
      case 'ESCALATED_TO_AUTHORITY':
        return const Color(0xFF185FA5);
      case 'CLOSED':
        return const Color(0xFF5F5E5A);
      case 'REJECTED':
        return const Color(0xFFA32D2D);
      default:
        return Colors.grey;
    }
  }

  Color _statusBg(String? status) {
    switch (status) {
      case 'ESCALATED_TO_CC':
        return const Color(0xFFEEEDFE);
      case 'UNDER_REVIEW':
        return const Color(0xFFFAEEDA);
      case 'ESCALATED_TO_AUTHORITY':
        return const Color(0xFFE6F1FB);
      case 'CLOSED':
        return const Color(0xFFF1EFE8);
      case 'REJECTED':
        return const Color(0xFFFCEBEB);
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
        return 'Escalated to authority';
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

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(escalationFilterProvider);
    final asyncEscalations = ref.watch(currentEscalationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Escalation worklist',
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
      body: Column(
        children: [
          const OfflineBanner(),
          _buildToolbar(filter),
          _buildCountBar(asyncEscalations, filter),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(escalationListProvider);
                ref.invalidate(currentEscalationsProvider);
              },
              child: AsyncValueWidget<Map<String, dynamic>>(
                value: asyncEscalations,
                onRetry: () => ref.invalidate(currentEscalationsProvider),
                data: (response) {
                  final items = (response['escalations'] as List?) ?? [];
                  final totalPages = response['totalPages'] as int? ?? 1;

                  if (items.isEmpty) {
                    return const EmptyState(
                      title: 'No escalations found',
                      subtitle: 'Try adjusting your filters or search query',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return _buildPagination(filter, totalPages);
                      }
                      final currentUser = ref
                          .watch(currentUserProvider)
                          .asData
                          ?.value;
                      return _buildCard(items[index] as Map, currentUser);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(EscalationFilter filter) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) =>
                ref.read(escalationFilterProvider.notifier).setSearch(v),
            decoration: InputDecoration(
              hintText: 'Search by driver, vehicle, type...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: filter.status != null
                      ? _statusLabel(filter.status)
                      : 'Status',
                  isActive: filter.status != null,
                  onTap: () => _showBottomSheet(
                    'Filter by status',
                    AppConstants.allEscalationStatuses
                        .map(_statusLabel)
                        .toList(),
                    (v) {
                      final idx = AppConstants.allEscalationStatuses
                          .map(_statusLabel)
                          .toList()
                          .indexOf(v);
                      ref
                          .read(escalationFilterProvider.notifier)
                          .setStatus(AppConstants.allEscalationStatuses[idx]);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: filter.type ?? 'Escalation type',
                  isActive: filter.type != null,
                  onTap: () => _showBottomSheet(
                    'Filter by type',
                    _types,
                    (v) =>
                        ref.read(escalationFilterProvider.notifier).setType(v),
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: filter.dateRange ?? 'Date range',
                  isActive: filter.dateRange != null,
                  onTap: () => _showBottomSheet(
                    'Filter by date',
                    _dateRanges,
                    (v) => ref
                        .read(escalationFilterProvider.notifier)
                        .setDateRange(v),
                  ),
                ),
                if (filter.hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      ref.read(escalationFilterProvider.notifier).clear();
                    },
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
                        'Clear',
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
    );
  }

  Widget _buildCountBar(
    AsyncValue<Map<String, dynamic>> async,
    EscalationFilter filter,
  ) {
    final total = async.asData?.value['total'] as int?;
    final label = total != null ? '$total escalations' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black45),
        ),
      ),
    );
  }

  Widget _buildPagination(EscalationFilter filter, int totalPages) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: filter.page > 1
                ? () => ref.read(escalationFilterProvider.notifier).prevPage()
                : null,
          ),
          Text(
            'Page ${filter.page} of $totalPages',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: filter.page < totalPages
                ? () => ref.read(escalationFilterProvider.notifier).nextPage()
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map e, CurrentUser? user) {
    final sevLevel = (e['severity_level'] as num?)?.toInt() ?? 1;
    final speed =
        double.tryParse(e['max_vehicle_speed']?.toString() ?? '') ?? 0;
    final gForce = double.tryParse(e['max_g_force']?.toString() ?? '') ?? 0;
    final conf = double.tryParse(e['confidence']?.toString() ?? '') ?? 0;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(e['created_at']),
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
                TextButton(
                  onPressed: () async {
                    final user = ref.read(currentUserProvider).value;

                    // BRD §4.3 — Organisation cannot update escalation status.
                    // Authority / Command Center / SuperAdmin mark it UNDER_REVIEW
                    // on open. Organisation just navigates directly to read-only view.
                    if (user?.canUpdateEscalationStatus == true) {
                      try {
                        await EscalationApi().updateEscalationStatus(
                          e['id'],
                          AppConstants.statusUnderReview,
                        );
                        ref.invalidate(escalationListProvider);
                        ref.invalidate(currentEscalationsProvider);
                      } catch (err) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update status: $err'),
                            ),
                          );
                          return;
                        }
                      }
                    }

                    if (mounted) {
                      Navigator.pushNamed(
                        context,
                        AppConstants.routeEscalationReview,
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

  void _showBottomSheet(
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
