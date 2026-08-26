class LocationSample {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double heading;
  final DateTime deviceTimestamp;

  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.deviceTimestamp,
  });

  @override
  String toString() {
    return 'LocationSample(lat: $latitude, lon: $longitude, accuracy: $accuracy, speed: $speed, time: $deviceTimestamp)';
  }
}
