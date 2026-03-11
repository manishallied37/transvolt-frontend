import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';

import '../widgets/kpi_card.dart';
import '../widgets/event_category_chart.dart';
import '../widgets/depot_overview_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool editMode = false;

  final ScrollController scrollController = ScrollController();

  late List<Widget> dashboardWidgets;

  @override
  void initState() {
    super.initState();

    dashboardWidgets = [
      const EventCategoryChart(
        key: ValueKey("chart"),
        critical: 12,
        high: 20,
        medium: 30,
        low: 40,
      ),

      const DepotOverviewCard(
        key: ValueKey("depotA"),
        depotName: "Depot A",
        events: 20,
      ),

      const DepotOverviewCard(
        key: ValueKey("depotB"),
        depotName: "Depot B",
        events: 15,
      ),

      const KpiCard(
        key: ValueKey("total"),
        title: "Total Events",
        value: "145",
        subtitle: "+8 today",
        color: Colors.green,
      ),

      const KpiCard(
        key: ValueKey("compliance"),
        title: "Compliance %",
        value: "96%",
        subtitle: "+1.2%",
        color: Colors.blue,
      ),

      const KpiCard(
        key: ValueKey("escalated"),
        title: "Escalated",
        value: "26",
        subtitle: "+5%",
        color: Colors.red,
      ),

      const KpiCard(
        key: ValueKey("resolved"),
        title: "Resolved",
        value: "112",
        subtitle: "+9",
        color: Colors.orange,
      ),
    ];
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

  Widget buildDashboardGrid() {
    return ReorderableWrap(
      spacing: 10,
      runSpacing: 10,

      needsLongPressDraggable: true,

      onReorder: _onReorder,

      buildDraggableFeedback: (context, constraints, child) {
        return Material(
          elevation: 18,
          borderRadius: BorderRadius.circular(12),

          child: Container(
            width: constraints.maxWidth,

            // decoration: BoxDecoration(
            //   borderRadius: BorderRadius.circular(12),
            //   border: Border.all(color: Colors.blueAccent, width: 2),
            // ),

            child: child,
          ),
        );
      },

      children: dashboardWidgets.map((widget) {
        bool isChart = widget.key == const ValueKey("chart");

        return Listener(
          key: widget.key,

          onPointerMove: (event) {
            final position = event.position.dy;
            final screenHeight = MediaQuery.of(context).size.height;

            /// scroll up
            if (position < 120 && scrollController.hasClients) {
              scrollController.animateTo(
                scrollController.offset - 40,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }

            /// scroll down
            if (position > screenHeight - 120 && scrollController.hasClients) {
              scrollController.animateTo(
                scrollController.offset + 40,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
              );
            }
          },

          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),

            child: SizedBox(
              width: isChart
                  ? double.infinity
                  : (MediaQuery.of(context).size.width - 48) / 2,

              height: isChart ? 340 : 160,

              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,

                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),

                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: widget,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildNormalGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,

      children: dashboardWidgets.map((widget) {
        bool isChart = widget.key == const ValueKey("chart");

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),

          child: SizedBox(
            width: isChart
                ? double.infinity
                : (MediaQuery.of(context).size.width - 48) / 2,

            height: isChart ? 340 : 160,

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),

              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),

                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: widget,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: "Dashboard",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_outlined),
            label: "Events",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.videocam_outlined),
            label: "Stream",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: "Reports",
          ),
        ],
      ),

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
                  const CircleAvatar(radius: 22, backgroundColor: Colors.grey),

                  Row(
                    children: [
                      IconButton(
                        icon: Icon(editMode ? Icons.check : Icons.edit),

                        onPressed: () {
                          setState(() {
                            editMode = !editMode;
                          });
                        },
                      ),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),

                        child: IconButton(
                          icon: const Icon(Icons.notifications_none),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const Text(
                "Welcome, John",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const Text(
                "Fleet Monitoring",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Row(
                children: const [
                  Chip(
                    label: Text("LIVE", style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green,
                  ),

                  SizedBox(width: 10),

                  Text("Updated 2 min ago"),
                ],
              ),

              const SizedBox(height: 24),

              editMode ? buildDashboardGrid() : buildNormalGrid(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
