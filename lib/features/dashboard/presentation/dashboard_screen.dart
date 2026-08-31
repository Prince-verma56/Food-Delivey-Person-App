import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/env.dart';
import '../../../core/networking/backend_service.dart';
import '../../../core/authentication/clerk_auth_service.dart';
import '../../tracking/presentation/rider_map_screen.dart';
import '../../../app/auth_wrapper.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/location_models.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _assignment;
  bool _isLoading = true;
  Timer? _pollingTimer;

  bool _isOnline = false;
  bool _isNetworkConnected = true;
  String _gpsStatusText = 'Waiting for connection';

  final LocationService _locationService = LocationService();
  Timer? _heartbeatTimer;
  StreamSubscription<LocationSample>? _locationSubscription;
  DateTime? _lastSync;
  bool _isUploadingLocation = false;

  @override
  void initState() {
    super.initState();
    _fetchAssignment();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchAssignment();
    });
    _checkInitialLocationState();
  }

  Future<void> _checkInitialLocationState() async {
    await _locationService.permissionStatus;
    await _locationService.isLocationServiceEnabled();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _heartbeatTimer?.cancel();
    _stopLocationStream();
    super.dispose();
  }

  Future<void> _fetchAssignment() async {
    final assignment = await BackendService().getActiveAssignment();
    if (mounted) {
      setState(() {
        _assignment = assignment;
        _isLoading = false;
      });
    }
  }

  void _logout() async {
    await ClerkAuthService().logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
    );
  }

  void _showApiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUrl = prefs.getString('api_url') ?? Env.defaultNextJsApiUrl;
    final controller = TextEditingController(text: currentUrl);

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Local Development Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your laptop\'s current local IP address API URL:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://192.168.1.X:3000/api',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setString('api_url', controller.text.trim());
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('API URL updated to: ${controller.text.trim()}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleOnlineStatus() async {
    if (_isOnline) {
      // Go Offline
      _stopLocationStream();
      setState(() {
        _isOnline = false;
        _gpsStatusText = 'Offline';
      });
      await BackendService().sendGeneralLocation(isOnline: false);
    } else {
      // Go Online
      bool granted = await _locationService.requestPermission();

      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to go online.')),
        );
        return;
      }

      bool serviceEnabled = await _locationService.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;
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
        return;
      }

      setState(() {
        _isOnline = true;
        _gpsStatusText = 'Connected';
      });

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
    final success = await BackendService().sendGeneralLocation(isOnline: true);
    if (mounted) {
      setState(() {
        _isNetworkConnected = success;
      });
    }
  }

  void _startLocationStream() {
    _locationService.startTracking();
    _locationSubscription = _locationService.locationStream.listen((location) async {
      // 1. Always update Fleet Map (General Presence)
      if (_isUploadingLocation) return;
      _isUploadingLocation = true;

      try {
        final success = await BackendService().sendGeneralLocation(
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
            ['assigned', 'picked_up', 'out_for_delivery'].contains(_assignment!['deliveryStatus'])) {
          await BackendService().sendLocation(
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
        
        if (mounted) {
          setState(() {
            if (success) {
              _lastSync = DateTime.now();
              _gpsStatusText = 'Live';
            } else {
              _gpsStatusText = 'Upload Failed';
            }
          });
        }
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

  String _getTimeAgo() {
    if (_lastSync == null) return "Never";
    final diff = DateTime.now().difference(_lastSync!);
    if (diff.inSeconds < 60) return "${diff.inSeconds} sec ago";
    return "${diff.inMinutes} min ago";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DT PIZZA'),
        backgroundColor: Colors.orange.shade400,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchAssignment();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Hello 👋',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Online/Offline Control
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isOnline ? Colors.green.shade200 : Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.circle, color: _isOnline ? Colors.green : Colors.grey, size: 16),
                              const SizedBox(width: 8),
                              Text('Status: ${_isOnline ? 'Online' : 'Offline'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Switch(
                            value: _isOnline,
                            onChanged: (_) => _toggleOnlineStatus(),
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                      if (_isOnline) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Network:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(_isNetworkConnected ? 'Connected' : 'Offline', style: TextStyle(color: _isNetworkConnected ? Colors.green : Colors.red)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Hardware GPS:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Connected', style: TextStyle(color: Colors.green)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Telemetry:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(_gpsStatusText, style: TextStyle(color: _gpsStatusText == 'Live' ? Colors.green : Colors.orange)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Last upload:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(_getTimeAgo()),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                if (_assignment == null)
                  const Expanded(
                    child: Center(
                      child: Text(
                        "No active delivery\nYou're ready for orders.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  )
                else ...[
                  const Text('Current Assignment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ORDER #${_assignment!['orderNumber'] ?? _assignment!['_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Customer: ${_assignment!['customer']?['name'] ?? 'Customer'}'),
                          Text('Destination: ${_assignment!['customer']?['address'] ?? 'Unknown'}'),
                          Text('Total: ₹${_assignment!['pricing']?['total'] ?? 0}'),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RiderMapScreen(assignment: _assignment!),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              child: const Text('START DELIVERY / TRACK', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ]
              ],
            ),
          ),
    );
  }
}
