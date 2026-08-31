import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'location_models.dart';

class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  final StreamController<LocationSample> _locationController = StreamController<LocationSample>.broadcast();
  
  LocationSample? _lastLocation;
  DateTime? _lastAcceptedLocationTime;
  
  // Configurable constants
  static const int locationUpdateIntervalSeconds = 1;
  static const int minimumMovementMeters = 1; 

  int _sequenceCounter = 1000;

  Stream<LocationSample> get locationStream => _locationController.stream;

  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<bool> get permissionStatus async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  void startTracking() async {
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return; // Handle GPS disabled state in UI
    }

    bool hasPermission = await permissionStatus;
    if (!hasPermission) {
      return; // Handle permission denied in UI
    }

    _positionStream?.cancel();
    
    // Use AndroidSettings for Foreground Service on Android
    late LocationSettings locationSettings;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: minimumMovementMeters,
        intervalDuration: const Duration(seconds: locationUpdateIntervalSeconds),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Location sharing active. You're online for deliveries.",
          notificationTitle: "DT Pizza Delivery",
          enableWakeLock: true,
        )
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: minimumMovementMeters,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: minimumMovementMeters,
      );
    }

    // Immediately fetch initial position to ensure Fleet Map gets a ping
    try {
      Position? position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        _processLocationUpdate(position);
      } else {
        position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 5));
        if (position != null) {
          _processLocationUpdate(position);
        }
      }
    } catch (e) {
      print("Failed to get initial location: $e");
    }

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) {
        if (position != null) {
          _processLocationUpdate(position);
        }
      },
      onError: (e) {
        print("Location Stream Error: $e");
      }
    );
  }

  void _processLocationUpdate(Position position) {
    // Rate Limiting (Step 12): Minimum 1 second between updates to prevent spamming
    final currentDeviceTime = DateTime.now();
    if (_lastAcceptedLocationTime != null && 
        currentDeviceTime.difference(_lastAcceptedLocationTime!).inMilliseconds < 1000) {
        return; // Too soon, ignore this update
    }
    
    _sequenceCounter++;
    
    final sample = LocationSample(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      deviceTimestamp: position.timestamp,
      sequence: _sequenceCounter,
    );
    
    print('TELEMETRY AUDIT: GPS Hardware Fix - seq=$_sequenceCounter, lat=${position.latitude}, lng=${position.longitude}');

    _lastLocation = sample;
    _lastAcceptedLocationTime = currentDeviceTime;
    
    _locationController.add(sample);
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  LocationSample? currentLocation() {
    return _lastLocation;
  }
}
