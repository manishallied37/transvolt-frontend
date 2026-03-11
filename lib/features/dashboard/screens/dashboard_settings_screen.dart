import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/dashboard_controller.dart';

import '../models/dashboard_widget_model.dart';

class DashboardSettingsScreen extends StatelessWidget {
  const DashboardSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final controller = Provider.of<DashboardController>(context);

    return Scaffold(

      appBar: AppBar(
        title: const Text("Dashboard Settings"),
      ),

      body: ListView.builder(

        itemCount: controller.widgets.length,

        itemBuilder: (context, index) {

          final widgetItem = controller.widgets[index];

          return SwitchListTile(

            title: Text(_getWidgetTitle(widgetItem.type)),

            value: widgetItem.visible,

            onChanged: (value) {

              controller.toggleWidget(index, value);

            },
          );
        },
      ),
    );
  }
}

String _getWidgetTitle(DashboardWidgetType type) {

  switch (type) {

    case DashboardWidgetType.totalEvents:
      return "KPI Cards";

    case DashboardWidgetType.compliance:
      return "Compliance";

    case DashboardWidgetType.escalated:
      return "Escalations";

    case DashboardWidgetType.eventChart:
      return "Event Chart";

    case DashboardWidgetType.depotA:
      return "Depot A";

    case DashboardWidgetType.depotB:
      return "Depot B";

    default:
      return "Widget";
  }
}