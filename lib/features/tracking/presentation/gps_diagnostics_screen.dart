import 'package:flutter/material.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/location_models.dart';
import '../../../core/networking/backend_service.dart';
import 'dart:async';

class GpsDiagnosticsScreen extends StatefulWidget {
  final String orderId;
  const GpsDiagnosticsScreen({super.key, required this.orderId});

  @override
  State<GpsDiagnosticsScreen> createState() => _GpsDiagnosticsScreenState();
}

class _GpsDiagnosticsScreenState extends State<GpsDiagnosticsScreen> {
  final LocationService _locationService = LocationService();
  StreamSubscription<LocationSample>? _locationSubscription;
  
  bool _permissionGranted = false;
  bool _gpsActive = false;
  bool _isTracking = false;
  bool _isBackendConnected = true;
  
  LocationSample? _currentLocation;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    _permissionGranted = await _locationService.permissionStatus;
    _gpsActive = await _locationService.isLocationServiceEnabled();
    _currentLocation = _locationService.currentLocation();
    
    // Subscribe to the unified location stream started by the Dashboard
    _locationSubscription = _locationService.locationStream.listen((location) {
      if (mounted) {
        setState(() {
          _currentLocation = location;
          _lastUpdateTime = DateTime.now();
          _isBackendConnected = true; 
        });
      }
    });
    
    setState(() {});
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    // Do NOT stop tracking here, Dashboard manages the lifecycle!
    super.dispose();
  }

  String _getTimeAgo() {
    if (_lastUpdateTime == null) return "Never";
    final diff = DateTime.now().difference(_lastUpdateTime!);
    if (diff.inSeconds < 60) return "${diff.inSeconds} sec ago";
    return "${diff.inMinutes} min ago";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DT PIZZA Delivery Partner'),
        backgroundColor: Colors.orange.shade400,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'GPS DIAGNOSTICS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 32),
            _buildStatusRow('Permission', _permissionGranted ? 'Granted' : 'Not granted', _permissionGranted),
            const SizedBox(height: 8),
            _buildStatusRow('GPS', _gpsActive ? 'Active' : 'Disabled', _gpsActive),
            const SizedBox(height: 8),
            _buildStatusRow('Network', _isBackendConnected ? 'Connected' : 'Offline', _isBackendConnected),
            const Divider(height: 32),
            if (!_isBackendConnected)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Unable to connect to backend. Please check your internet or if the server is running.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _buildInfoRow('Last Location', 'Updated ${_getTimeAgo()}'),
            _buildInfoRow('Accuracy', _currentLocation != null ? '${_currentLocation!.accuracy.toStringAsFixed(1)} m' : 'Unknown'),
            _buildInfoRow('Speed', _currentLocation != null ? '${(_currentLocation!.speed * 3.6).toStringAsFixed(1)} km/h' : '0 km/h'),
            _buildInfoRow('Heading', _currentLocation != null ? '${_currentLocation!.heading.toStringAsFixed(1)}°' : 'Unknown'),
            _buildInfoRow('GPS Timestamp', _currentLocation != null ? '${_currentLocation!.deviceTimestamp.millisecondsSinceEpoch}' : 'Unknown'),
            _buildInfoRow('Updates sent (Global)', '${BackendService().updatesSent}'),
            _buildInfoRow('Updates failed (Global)', '${BackendService().updatesFailed}'),
            
            const Spacer(),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Tracking is automatically managed by your Online status in the Dashboard.',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String status, bool isGood) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        Row(
          children: [
            Icon(
              isGood ? Icons.check_circle : Icons.cancel,
              color: isGood ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(status, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
