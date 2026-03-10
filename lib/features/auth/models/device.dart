class Device {
  final int id;
  final int userId;
  final String deviceId;
  final String deviceName;
  final String createdAt;

  Device({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.deviceName,
    required this.createdAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      userId: json['user_id'] ?? 0,
      deviceId: json['device_id'] ?? '',
      deviceName: json['device_name'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
