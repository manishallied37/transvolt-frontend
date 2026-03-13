class AlertModel {
  final int severity;
  final String type;
  final String status;

  AlertModel({
    required this.severity,
    required this.type,
    required this.status,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      severity: json["details"]["severity"],
      type: json["details"]["typeDescription"],
      status: json["status"],
    );
  }
}
