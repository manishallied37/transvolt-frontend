class User {
  final int id;
  final String username;
  final String password;
  final String role;
  final String region;
  final String depot;
  final String? deviceId;
  final bool mfaEnabled;
  final bool isActive;
  final String? email;
  final String? mobile_number;

  User({
    required this.id,
    required this.username,
    required this.password,
    required this.role,
    required this.region,
    required this.depot,
    required this.deviceId,
    required this.mfaEnabled,
    required this.isActive,
    required this.email,
    required this.mobile_number,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      role: json['role'] ?? '',
      region: json['region'] ?? '',
      depot: json['depot'] ?? '',
      deviceId: json['device_id'],
      mfaEnabled: json['mfa_enabled'] ?? true,
      isActive: json['is_active'] ?? true,
      email: json['email'],
      mobile_number: json['mobile_number'],
    );
  }
}
