import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import '../../../shared/models/dashboard_widget_model.dart';
import '../models/dashboard_widget_model.dart';

class DashboardController extends ChangeNotifier {

  /// Default layout
  final List<DashboardWidgetModel> defaultWidgets = [
    DashboardWidgetModel(type: DashboardWidgetType.depotA, visible: true, order: 0),
    DashboardWidgetModel(type: DashboardWidgetType.depotB, visible: true, order: 1),
    DashboardWidgetModel(type: DashboardWidgetType.totalEvents, visible: true, order: 2),
    DashboardWidgetModel(type: DashboardWidgetType.compliance, visible: true, order: 3),
    DashboardWidgetModel(type: DashboardWidgetType.escalated, visible: true, order: 4),
    DashboardWidgetModel(type: DashboardWidgetType.resolved, visible: true, order: 5),
    DashboardWidgetModel(type: DashboardWidgetType.eventChart, visible: true, order: 6),
  ];

  /// Widgets used by UI (initialized immediately)
  List<DashboardWidgetModel> widgets = [];

  DashboardController() {
    // IMPORTANT: initialize synchronously so UI has data immediately
    widgets = List.from(defaultWidgets);

    // Then try loading saved layout
    loadLayout();
  }

  /// Load saved layout
  Future<void> loadLayout() async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove("dashboard_layout"); // reset old layout

    final saved = prefs.getString("dashboard_layout");

    if (saved == null) {
      widgets = defaultWidgets;
      notifyListeners();
      return;
    }

    try {

      final decoded = jsonDecode(saved);

      widgets = decoded.map<DashboardWidgetModel>((item) {

        return DashboardWidgetModel(
          type: DashboardWidgetType.values[item["type"]],
          visible: item["visible"],
          order: item["order"],
        );

      }).toList();

    } catch (e) {

      // If saved layout is incompatible with new widget types
      widgets = defaultWidgets;

    }

    notifyListeners();
  }
  /// Save layout
  Future<void> saveLayout() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = widgets.map((w) {
      return {
        "type": w.type.index,
        "visible": w.visible,
        "order": w.order,
      };
    }).toList();

    await prefs.setString("dashboard_layout", jsonEncode(encoded));
  }

  /// Reorder widgets
  void reorderWidgets(int oldIndex, int newIndex) {

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final item = widgets.removeAt(oldIndex);
    widgets.insert(newIndex, item);

    saveLayout();
    notifyListeners();
  }

  /// Toggle widget visibility
  void toggleWidget(int index, bool value) {
    widgets[index].visible = value;
    saveLayout();
    notifyListeners();
  }
}