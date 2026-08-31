class LocationSample {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double heading;
  final DateTime deviceTimestamp;
  final int sequence;

  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.deviceTimestamp,
    required this.sequence,
  });

  @override
  String toString() {
    return 'LocationSample(seq: $sequence, lat: $latitude, lon: $longitude, accuracy: $accuracy, speed: $speed, time: $deviceTimestamp)';
  }
}
