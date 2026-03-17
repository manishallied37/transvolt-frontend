class DashboardKpiModel {
  final int totalEvents;
  final double compliance;
  final int escalated;
  final int resolved;

  final int critical;
  final int high;
  final int medium;
  final int low;

  final Map<String, int> depotSummary;

  DashboardKpiModel({
    required this.totalEvents,
    required this.compliance,
    required this.escalated,
    required this.resolved,
    required this.critical,
    required this.high,
    required this.medium,
    required this.low,
    required this.depotSummary,
  });

  factory DashboardKpiModel.fromJson(Map<String, dynamic> json) {
    return DashboardKpiModel(
      totalEvents: json["totalEvents"],
      compliance: (json["compliance"] as num).toDouble(),
      escalated: json["escalated"],
      resolved: json["resolved"],
      critical: json["critical"],
      high: json["high"],
      medium: json["medium"],
      low: json["low"],
      depotSummary: Map<String, int>.from(json["depotSummary"] ?? {}),
    );
  }
}
