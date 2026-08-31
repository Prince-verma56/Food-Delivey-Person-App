import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/networking/backend_service.dart';
import '../../core/location/location_service.dart';
import '../../core/location/location_models.dart';

class RiderStateProvider extends ChangeNotifier {
  final BackendService _backendService = BackendService();
  final LocationService _locationService = LocationService();

  Map<String, dynamic>? _assignment;
  bool _isLoadingAssignment = true;
  Timer? _pollingTimer;

  bool _isOnline = false;
  bool _isNetworkConnected = true;
  String _gpsStatusText = 'Waiting for connection';
  
  Timer? _heartbeatTimer;
  StreamSubscription<LocationSample>? _locationSubscription;
  DateTime? _lastSync;
  bool _isUploadingLocation = false;

  // Getters
  Map<String, dynamic>? get assignment => _assignment;
  bool get isLoadingAssignment => _isLoadingAssignment;
  bool get isOnline => _isOnline;
  bool get isNetworkConnected => _isNetworkConnected;
  String get gpsStatusText => _gpsStatusText;
  DateTime? get lastSync => _lastSync;

  RiderStateProvider() {
    _init();
  }

  void _init() {
    _fetchAssignment();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchAssignment();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _heartbeatTimer?.cancel();
    _stopLocationStream();
    super.dispose();
  }

  Future<void> _fetchAssignment() async {
    final assignment = await _backendService.getActiveAssignment();
    _assignment = assignment;
    _isLoadingAssignment = false;
    notifyListeners();
  }

  Future<void> refreshAssignment() async {
    _isLoadingAssignment = true;
    notifyListeners();
    await _fetchAssignment();
  }

  Future<void> toggleOnlineStatus(BuildContext context) async {
    if (_isOnline) {
      // Go Offline
      _stopLocationStream();
      _isOnline = false;
      _gpsStatusText = 'Offline';
      notifyListeners();
      await _backendService.sendGeneralLocation(isOnline: false);
    } else {
      // Go Online
      bool granted = await _locationService.requestPermission();

      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required to go online.')),
          );
        }
        return;
      }

      bool serviceEnabled = await _locationService.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Device Location (GPS) is turned off.'),
              action: SnackBarAction(
                label: 'TURN ON',
                onPressed: () {
                  _locationService.openLocationSettings();
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      _isOnline = true;
      _gpsStatusText = 'Connected';
      notifyListeners();

      // Send initial presence ping immediately
      _sendHeartbeat();

      // Start Stream
      _startLocationStream();
      
      // Start Heartbeat Timer (every 30 seconds)
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _sendHeartbeat();
      });
    }
  }

  Future<void> _sendHeartbeat() async {
    final success = await _backendService.sendGeneralLocation(isOnline: true);
    _isNetworkConnected = success;
    notifyListeners();
  }

  void _startLocationStream() {
    _locationService.startTracking();
    _locationSubscription = _locationService.locationStream.listen((location) async {
      // 1. Always update Fleet Map (General Presence)
      if (_isUploadingLocation) return;
      _isUploadingLocation = true;

      try {
        final success = await _backendService.sendGeneralLocation(
          isOnline: true,
          latitude: location.latitude,
          longitude: location.longitude,
          heading: location.heading,
          speed: location.speed,
          accuracy: location.accuracy,
          gpsTimestamp: location.deviceTimestamp.millisecondsSinceEpoch,
          sequence: location.sequence,
        );
        
        // 2. If assigned to an order, ALSO update Order Map
        if (_assignment != null && _assignment!['_id'] != null && 
            ['assigned', 'picked_up', 'out_for_delivery', 'on_the_way'].contains(_assignment!['deliveryStatus'])) {
          await _backendService.sendLocation(
            orderId: _assignment!['_id'],
            latitude: location.latitude,
            longitude: location.longitude,
            heading: location.heading,
            speed: location.speed,
            accuracy: location.accuracy,
            gpsTimestamp: location.deviceTimestamp.millisecondsSinceEpoch,
            sequence: location.sequence,
          );
        }
        
        if (success) {
          _lastSync = DateTime.now();
          _gpsStatusText = 'Live';
        } else {
          _gpsStatusText = 'Upload Failed';
        }
        notifyListeners();
      } finally {
        _isUploadingLocation = false;
      }
    });
  }

  void _stopLocationStream() {
    _locationService.stopTracking();
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
