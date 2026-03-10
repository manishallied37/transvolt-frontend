class RefreshToken {
  final int id;
  final int userId;
  final String token;
  final String? deviceId;
  final String createdAt;
  final String? expiresAt;
  final bool revoked;

  RefreshToken({
    required this.id,
    required this.userId,
    required this.token,
    required this.deviceId,
    required this.createdAt,
    required this.expiresAt,
    required this.revoked,
  });

  factory RefreshToken.fromJson(Map<String, dynamic> json) {
    return RefreshToken(
      id: json['id'] as int,
      userId: json['user_id'] ?? 0,
      token: json['token'] ?? '',
      deviceId: json['device_id'],
      createdAt: json['created_at'] ?? '',
      expiresAt: json['expires_at'],
      revoked: json['revoked'] ?? false,
    );
  }
}
