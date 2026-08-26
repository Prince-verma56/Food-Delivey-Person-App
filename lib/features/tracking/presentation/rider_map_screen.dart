import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/location_models.dart';
import '../../../core/networking/routing_service.dart';
import '../../../core/networking/backend_service.dart';
import '../../../core/config/env.dart';

class RiderMapScreen extends StatefulWidget {
  final Map<String, dynamic> assignment;

  const RiderMapScreen({super.key, required this.assignment});

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<LocationSample>? _locationSub;
  LocationSample? _currentLocation;

  List<LatLng> _routePoints = [];
  double? _distance;
  double? _duration;

  bool _followDriver = true;

  LatLng get _restaurantLocation {
    final loc = widget.assignment['restaurantLocation'];
    if (loc != null) {
      return LatLng(loc['latitude'], loc['longitude']);
    }
    return const LatLng(27.4924, 77.6737); // Fallback
  }

  LatLng get _customerLocation {
    final loc = widget.assignment['customerLocation'];
    if (loc != null) {
      return LatLng(loc['latitude'], loc['longitude']);
    }
    return const LatLng(27.5000, 77.6800); // Fallback
  }

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _fetchRoute();
  }

  void _startLocationUpdates() {
    _locationSub = LocationService().locationStream.listen((loc) {
      if (!mounted) return;
      setState(() {
        _currentLocation = loc;
      });

      if (_followDriver) {
        _mapController.moveAndRotate(
          LatLng(loc.latitude, loc.longitude),
          16.0,
          loc.heading ?? 0.0,
        );
      }
    });
  }

  Future<void> _fetchRoute() async {
    final route = await RoutingService().getRoute(_restaurantLocation, _customerLocation);
    if (route != null && mounted) {
      setState(() {
        _routePoints = route['points'];
        _distance = route['distance'];
        _duration = route['duration'];
      });
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderNumber = widget.assignment['orderNumber'] ?? widget.assignment['_id'] ?? 'Unknown';
    final customerName = widget.assignment['customer']?['name'] ?? 'Customer';
    final deliveryStatus = widget.assignment['deliveryStatus'] ?? 'assigned';

    final etaMinutes = _duration != null ? (_duration! / 60).ceil() : '--';
    final distanceKm = _distance != null ? (_distance! / 1000).toStringAsFixed(1) : '--';
    final speedKmH = _currentLocation?.speed != null ? (_currentLocation!.speed * 3.6).toStringAsFixed(1) : '0.0';

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$orderNumber'),
        backgroundColor: Colors.orange.shade400,
        actions: [
          IconButton(
            icon: Icon(
              Icons.my_location,
              color: _followDriver ? Colors.white : Colors.black54,
            ),
            tooltip: 'Recenter & Follow',
            onPressed: () {
              setState(() {
                _followDriver = true;
              });
              if (_currentLocation != null) {
                _mapController.moveAndRotate(
                  LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
                  16.0,
                  _currentLocation!.heading ?? 0.0,
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _restaurantLocation,
              initialZoom: 14.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _followDriver) {
                  setState(() => _followDriver = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                additionalOptions: {
                  'accessToken': Env.mapBoxToken,
                },
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      color: Colors.orange.shade600,
                      strokeWidth: 4.0,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _restaurantLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.store, color: Colors.orange, size: 40),
                  ),
                  Marker(
                    point: _customerLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                  ),
                  if (_currentLocation != null)
                    Marker(
                      point: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
                      width: 60,
                      height: 60,
                      child: Transform.rotate(
                        angle: (_currentLocation!.heading ?? 0) * (3.14159 / 180),
                        child: const Icon(Icons.motorcycle, color: Colors.green, size: 50),
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          // Top Status Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivering to $customerName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_currentLocation != null)
                          Text(
                            'GPS Accuracy: ${_currentLocation!.accuracy.toStringAsFixed(1)}m',
                            style: TextStyle(
                              color: _currentLocation!.accuracy <= 20 ? Colors.green : Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Stats Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('ETA', '$etaMinutes min', Icons.timer),
                      _buildStatColumn('Distance', '$distanceKm km', Icons.route),
                      _buildStatColumn('Speed', '$speedKmH km/h', Icons.speed),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade500,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final orderId = widget.assignment['_id'];
                        if (orderId == null) return;
                        
                        String action = '';
                        if (deliveryStatus == 'assigned' || deliveryStatus == 'picked_up') {
                          action = 'start_delivery';
                        } else if (deliveryStatus == 'out_for_delivery') {
                          action = 'complete_delivery';
                        }
                        
                        if (action.isNotEmpty) {
                          final success = await BackendService().updateDeliveryStatus(orderId: orderId, action: action);
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Status updated successfully!')),
                            );
                            if (action == 'complete_delivery') {
                              Navigator.pop(context); // Go back to dashboard when done
                            }
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to update status.')),
                            );
                          }
                        }
                      },
                      child: Text(
                        (deliveryStatus == 'assigned' || deliveryStatus == 'picked_up') ? 'START DELIVERY' 
                        : deliveryStatus == 'out_for_delivery' ? 'COMPLETE DELIVERY' 
                        : deliveryStatus.toString().toUpperCase().replaceAll('_', ' '),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }
}
