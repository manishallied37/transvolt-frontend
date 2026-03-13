import '../models/alert_model.dart';
import '../services/alert_service.dart';

class AlertController {

  Future<Map<String, dynamic>> getDashboardMetrics() async {

    List<AlertModel> alerts = await AlertService.fetchAlerts();

    int total = alerts.length;

    int escalated = alerts.where((a) => a.severity == 1).length;

    int resolved = alerts.where((a) => a.status == "CONFIRMED").length;

    int complianceEvents = alerts
        .where((a) =>
    a.type == "SEATBELT-COMPLIANCE" ||
        a.type == "FACE-MASK-COMPLIANCE")
        .length;

    int compliance = total == 0
        ? 0
        : ((complianceEvents / total) * 100).round();

    int critical = alerts.where((a) => a.severity == 1).length;
    int high = alerts.where((a) => a.severity == 2).length;
    int medium = alerts.where((a) => a.severity == 3).length;
    int low = alerts.where((a) => a.severity == 4).length;

    return {
      "total": total,
      "escalated": escalated,
      "resolved": resolved,
      "compliance": compliance,
      "critical": critical,
      "high": high,
      "medium": medium,
      "low": low,
      "alertCount": alerts.length,
      "latestAlert": alerts.isNotEmpty ? alerts.first : null
    };
  }
}