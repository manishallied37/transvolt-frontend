import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/escalation/services/escalation_api.dart';

class EscalationFilter {
  final String? status;
  final String? type;
  final String? dateRange;
  final String search;
  final int page;
  final int limit;

  const EscalationFilter({
    this.status,
    this.type,
    this.dateRange,
    this.search = '',
    this.page = 1,
    this.limit = 20,
  });

  EscalationFilter copyWith({
    String? status,
    String? type,
    String? dateRange,
    String? search,
    int? page,
    int? limit,
    bool clearStatus = false,
    bool clearType = false,
    bool clearDateRange = false,
  }) {
    return EscalationFilter(
      status: clearStatus ? null : (status ?? this.status),
      type: clearType ? null : (type ?? this.type),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      search: search ?? this.search,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  bool get hasActiveFilters =>
      status != null || type != null || dateRange != null || search.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EscalationFilter &&
          status == other.status &&
          type == other.type &&
          dateRange == other.dateRange &&
          search == other.search &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode =>
      status.hashCode ^
      type.hashCode ^
      dateRange.hashCode ^
      search.hashCode ^
      page.hashCode ^
      limit.hashCode;
}

// ── Filter notifier ───────────────────────────────────────────
class EscalationFilterNotifier extends Notifier<EscalationFilter> {
  @override
  EscalationFilter build() => const EscalationFilter();

  void setStatus(String? status) => state = state.copyWith(
    status: status,
    clearStatus: status == null,
    page: 1,
  );

  void setType(String? type) =>
      state = state.copyWith(type: type, clearType: type == null, page: 1);

  void setDateRange(String? range) => state = state.copyWith(
    dateRange: range,
    clearDateRange: range == null,
    page: 1,
  );

  void setSearch(String search) =>
      state = state.copyWith(search: search, page: 1);

  void nextPage() => state = state.copyWith(page: state.page + 1);

  void prevPage() {
    if (state.page > 1) state = state.copyWith(page: state.page - 1);
  }

  void clear() => state = const EscalationFilter();
}

final escalationFilterProvider =
    NotifierProvider<EscalationFilterNotifier, EscalationFilter>(
      EscalationFilterNotifier.new,
    );

// ── Escalation list provider ──────────────────────────────────
// Cached per filter state — won't re-fetch if filter hasn't changed
final escalationListProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    final filter = ref.watch(escalationFilterProvider);

    final api = EscalationApi();

    final response = await api.getEscalations(
      page: filter.page,
      limit: filter.limit,
      status: filter.status,
      type: filter.type,
      dateRange: filter.dateRange,
      search: filter.search,
    );

    return response as Map<String, dynamic>;
  },
);
// ── Combined provider: current filter → list ──────────────────
final currentEscalationsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
      return ref.watch(escalationListProvider.future);
    });
