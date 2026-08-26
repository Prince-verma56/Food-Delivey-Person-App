import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import 'package:latlong2/latlong.dart';

class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  /// Returns map with points, distance (meters), duration (seconds)
  Future<Map<String, dynamic>?> getRoute(
      LatLng start, LatLng end) async {
    try {
      final url =
          'https://api.mapbox.com/directions/v5/mapbox/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&access_token=${Env.mapBoxToken}';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List<dynamic>;
          
          List<LatLng> points = geometry
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();

          return {
            'points': points,
            'distance': route['distance'],
            'duration': route['duration']
          };
        }
      }
      return null;
    } catch (e) {
      print('Mapbox Routing Error: $e');
      return null;
    }
  }
}
