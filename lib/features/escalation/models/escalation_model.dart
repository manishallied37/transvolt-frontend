class EscalationModel {

  final String id;
  final String eventId;
  final String vehicleId;
  final String driverName;
  final String severity;
  final String status;

  EscalationModel({
    required this.id,
    required this.eventId,
    required this.vehicleId,
    required this.driverName,
    required this.severity,
    required this.status,
  });

  factory EscalationModel.fromJson(Map<String, dynamic> json) {

    return EscalationModel(
      id: json["id"],
      eventId: json["event_id"],
      vehicleId: json["vehicle_id"],
      driverName: json["driver_name"],
      severity: json["severity"],
      status: json["status"],
    );
  }

}