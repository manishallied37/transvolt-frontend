class StreamLaunchArgs {
  final String? vehicleNumber;
  final String? vin;
  final String? licensePlateNumber;
  final String? cameraId;
  final bool autoPlay;

  const StreamLaunchArgs({
    this.vehicleNumber,
    this.vin,
    this.licensePlateNumber,
    this.cameraId,
    this.autoPlay = false,
  });

  bool get hasVehicleIdentifier =>
      (vehicleNumber ?? '').trim().isNotEmpty ||
      (vin ?? '').trim().isNotEmpty ||
      (licensePlateNumber ?? '').trim().isNotEmpty;
}
