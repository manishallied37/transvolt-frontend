enum DashboardWidgetType {
  depotA,
  depotB,
  totalEvents,
  compliance,
  escalated,
  resolved,
  eventChart,
}

class DashboardWidgetModel {

  final DashboardWidgetType type;
  bool visible;
  int order;

  DashboardWidgetModel({
    required this.type,
    required this.visible,
    required this.order,
  });

}