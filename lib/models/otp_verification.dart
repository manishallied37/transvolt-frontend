class OtpVerification {
  final int id;
  final String email;
  final String otp;
  final String expiresAt;

  OtpVerification({
    required this.id,
    required this.email,
    required this.otp,
    required this.expiresAt,
  });

  factory OtpVerification.fromJson(Map<String, dynamic> json) {
    return OtpVerification(
      id: json['id'] as int,
      email: json['email'] ?? '',
      otp: json['otp'] ?? '',
      expiresAt: json['expires_at'] ?? '',
    );
  }
}
