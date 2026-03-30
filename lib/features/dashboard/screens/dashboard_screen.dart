import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';

import '../../../core/services/dashboard_api_service.dart';
import '../../../core/models/dashboard_kpi_model.dart';
import '../../../core/utils/polling_service.dart';

import '../../auth/services/token_storage.dart';

import '../widgets/kpi_card.dart';
import '../widgets/event_category_chart.dart';
import '../widgets/depot_overview_card.dart';

import '../controllers/alert_controller.dart';
import '../models/alert_model.dart';
import '../../../core/config/rbac.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool editMode = false;

  final ScrollController scrollController = ScrollController();

  final AlertController alertController = AlertController();

  final PollingService pollingService = PollingService(
    baseInterval: const Duration(seconds: 5),
  );

  DashboardKpiModel? dashboardData;

  int alertCount = 0;

  late List<Widget> dashboardWidgets;

  @override
  void initState() {
    super.initState();

    loadDashboardData();

    startAlertPolling();
  }

  Future<void> loadDashboardData() async {
    dashboardData = await DashboardApiService.fetchDashboardData();

    dashboardWidgets = [
      EventCategoryChart(
        key: const ValueKey("chart"),
        critical: dashboardData?.critical ?? 0,
        high: dashboardData?.high ?? 0,
        medium: dashboardData?.medium ?? 0,
        low: dashboardData?.low ?? 0,
      ),

      DepotOverviewCard(
        key: const ValueKey("depotA"),
        depotName: "Depot A",
        events: dashboardData?.depotSummary["Depot A"] ?? 0,
      ),

      DepotOverviewCard(
        key: const ValueKey("depotB"),
        depotName: "Depot B",
        events: dashboardData?.depotSummary["Depot B"] ?? 0,
      ),

      KpiCard(
        key: const ValueKey("total"),
        title: "Total Events",
        value: (dashboardData?.totalEvents ?? 0).toString(),
        subtitle: "Today",
        color: Colors.green,
      ),

      KpiCard(
        key: const ValueKey("compliance"),
        title: "Compliance %",
        value: "${dashboardData?.compliance ?? 0}%",
        subtitle: "Driver Safety",
        color: Colors.blue,
      ),

      KpiCard(
        key: const ValueKey("escalated"),
        title: "Escalated",
        value: (dashboardData?.escalated ?? 0).toString(),
        subtitle: "Critical Alerts",
        color: Colors.red,
      ),

      KpiCard(
        key: const ValueKey("resolved"),
        title: "Resolved",
        value: (dashboardData?.resolved ?? 0).toString(),
        subtitle: "Closed Alerts",
        color: Colors.orange,
      ),
    ];

    setState(() {});
  }

  /// Poll alerts automatically
  void startAlertPolling() {
    pollingService.start(task: fetchAlerts);
  }

  /// Fetch alerts
  Future<void> fetchAlerts() async {
    final alertMetrics = await alertController.getDashboardMetrics();

    int newCount = alertMetrics["alertCount"] ?? 0;

    if (newCount != alertCount) {
      setState(() {
        alertCount = newCount;
      });

      if (alertMetrics["latestAlert"] != null) {
        showAlertPopup(alertMetrics["latestAlert"]);
      }
    }
  }

  /// Alert popup
  void showAlertPopup(AlertModel alert) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("🚨 New Alert"),

          content: Text("${alert.type}\nStatus: ${alert.status}"),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Dismiss"),
            ),
          ],
        );
      },
    );
  }

  Future<void> logout() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),

        content: const Text("Are you sure you want to logout?"),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await TokenStorage.clearTokens();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }

  Future<bool> _onBackPressed() async {
    await logout();

    return false;
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (!editMode) return;

    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final item = dashboardWidgets.removeAt(oldIndex);

      dashboardWidgets.insert(newIndex, item);
    });
  }

  // ── Responsive helpers ────────────────────────────────────────────────────

  /// Number of KPI card columns based on available screen width.
  /// Phone  (<600):  2 columns
  /// Tablet (600–899): 3 columns
  /// Large  (≥900):  4 columns
  int _kpiColumnCount(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  /// Width of a single KPI card given the current screen width.
  double _kpiCardWidth(double screenWidth) {
    const double padding = 32; // 16 left + 16 right
    const double spacing = 10;
    final int cols = _kpiColumnCount(screenWidth);
    return (screenWidth - padding - spacing * (cols - 1)) / cols;
  }

  Widget buildDashboardGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = _kpiCardWidth(screenWidth);
    // Chart is always full width
    const double chartHeight = 340;
    const double kpiHeight = 160;

    return ReorderableWrap(
      spacing: 10,
      runSpacing: 10,
      needsLongPressDraggable: true,
      onReorder: _onReorder,
      children: dashboardWidgets.map((widget) {
        final bool isChart = widget.key == const ValueKey("chart");
        return Container(
          key: widget.key,
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: SizedBox(
            width: isChart ? double.infinity : cardWidth,
            height: isChart ? chartHeight : kpiHeight,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: widget,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildNormalGrid() {
    if (dashboardData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = _kpiCardWidth(screenWidth);
    const double chartHeight = 340;
    const double kpiHeight = 160;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: dashboardWidgets.map((widget) {
        final bool isChart = widget.key == const ValueKey("chart");
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: SizedBox(
            width: isChart ? double.infinity : cardWidth,
            height: isChart ? chartHeight : kpiHeight,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: widget,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    pollingService.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        await _onBackPressed();
      },

      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            controller: scrollController,

            physics: const ClampingScrollPhysics(),

            padding: const EdgeInsets.symmetric(horizontal: 16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == "logout") {
                          logout();
                        }
                      },

                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: "logout",
                          child: Row(
                            children: [
                              Icon(Icons.logout),
                              SizedBox(width: 10),
                              Text("Logout"),
                            ],
                          ),
                        ),
                      ],

                      child: const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person),
                      ),
                    ),

                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            widget.onNavigate(1);
                          },

                          child: Stack(
                            children: [
                              const Icon(Icons.notifications_none, size: 28),

                              if (alertCount > 0)
                                Positioned(
                                  right: 0,

                                  top: 0,

                                  child: Container(
                                    padding: const EdgeInsets.all(4),

                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),

                                    child: Text(
                                      alertCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        IconButton(
                          icon: Icon(editMode ? Icons.check : Icons.edit),

                          onPressed: () {
                            setState(() {
                              editMode = !editMode;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Consumer(
                  builder: (context, ref, _) {
                    final userAsync = ref.watch(currentUserProvider);
                    return userAsync.when(
                      loading: () => const Text(
                        'Welcome',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (user) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${user.username != null && user.username!.isNotEmpty ? user.username![0].toUpperCase() + user.username!.substring(1) : 'User'}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _roleBadgeColor(user.role)['bg'],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user.displayRole,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _roleBadgeColor(user.role)['text'],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const Text(
                  "Fleet Monitoring",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 24),

                editMode ? buildDashboardGrid() : buildNormalGrid(),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, Color> _roleBadgeColor(String? role) {
    switch (role) {
      case AppRole.superAdmin:
        return {'bg': const Color(0xFFEEEDFE), 'text': const Color(0xFF534AB7)};
      case AppRole.authority:
        return {'bg': const Color(0xFFFAEEDA), 'text': const Color(0xFF854F0B)};
      case AppRole.commandCenter:
        return {'bg': const Color(0xFFE6F1FB), 'text': const Color(0xFF185FA5)};
      case AppRole.organisation:
        return {'bg': const Color(0xFFEAF3DE), 'text': const Color(0xFF3B6D11)};
      default:
        return {'bg': const Color(0xFFF1EFE8), 'text': const Color(0xFF5F5E5A)};
    }
  }
}
