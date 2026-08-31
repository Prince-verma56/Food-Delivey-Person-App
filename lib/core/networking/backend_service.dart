import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../authentication/clerk_auth_service.dart';

class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  int updatesSent = 0;
  int updatesFailed = 0;

  // Offline Telemetry Buffer (Phase 4E)
  final List<Map<String, dynamic>> _generalLocationBuffer = [];
  final List<Map<String, dynamic>> _orderLocationBuffer = [];
  bool _isFlushing = false;

  Future<bool> sendLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
    int? gpsTimestamp,
    int? sequence,
  }) async {
    final token = await ClerkAuthService().getValidToken();
    if (token == null) return false;

    try {
      final requestSentAt = DateTime.now().millisecondsSinceEpoch;
      final apiUrl = await Env.getNextJsApiUrl();
      final response = await http.post(
        Uri.parse('$apiUrl/driver/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'orderId': orderId,
          'latitude': latitude,
          'longitude': longitude,
          'heading': heading,
          'speed': speed,
          'accuracy': accuracy,
          'gpsTimestamp': gpsTimestamp ?? DateTime.now().millisecondsSinceEpoch,
          'sequence': sequence,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Backend Error: ${response.statusCode} - ${response.body}');
        updatesFailed++;
        return false;
      }

      final latency = DateTime.now().millisecondsSinceEpoch - requestSentAt;
      print('TELEMETRY AUDIT: Sent seq=$sequence, gpsTs=$gpsTimestamp, backendLat=$latency ms');
      updatesSent++;
      
      // Flush buffer on successful connection
      _flushBuffers();
      return true;
    } on TimeoutException catch (_) {
      print('Location Sync Timeout');
      updatesFailed++;
      _bufferOrderLocation(orderId, latitude, longitude, heading, speed, accuracy, gpsTimestamp, sequence);
      return false;
    } catch (e) {
      print('Location Sync Error: $e');
      updatesFailed++;
      _bufferOrderLocation(orderId, latitude, longitude, heading, speed, accuracy, gpsTimestamp, sequence);
      return false;
    }
  }

  void _bufferOrderLocation(String orderId, double lat, double lng, double? h, double? s, double? acc, int? ts, int? seq) {
    if (_orderLocationBuffer.length >= 60) {
      _orderLocationBuffer.removeAt(0); // Cap buffer to last 60 points (~1 min of dense data, or 5 mins of stationary)
    }
    _orderLocationBuffer.add({
      'orderId': orderId,
      'latitude': lat,
      'longitude': lng,
      'heading': h,
      'speed': s,
      'accuracy': acc,
      'gpsTimestamp': ts ?? DateTime.now().millisecondsSinceEpoch,
      'sequence': seq,
    });
  }

  Future<bool> sendGeneralLocation({
    required bool isOnline,
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
    double? accuracy,
    int? gpsTimestamp,
    int? sequence,
  }) async {
    final token = await ClerkAuthService().getValidToken();
    if (token == null) return false;

    try {
      final requestSentAt = DateTime.now().millisecondsSinceEpoch;
      final apiUrl = await Env.getNextJsApiUrl();
      final response = await http.post(
        Uri.parse('$apiUrl/driver/location/general'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'isOnline': isOnline,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (heading != null) 'heading': heading,
          if (speed != null) 'speed': speed,
          if (accuracy != null) 'accuracy': accuracy,
          if (gpsTimestamp != null) 'gpsTimestamp': gpsTimestamp,
          if (sequence != null) 'sequence': sequence,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Backend General Location Error: ${response.statusCode} - ${response.body}');
        return false;
      }

      if (latitude != null) {
        final latency = DateTime.now().millisecondsSinceEpoch - requestSentAt;
        print('TELEMETRY AUDIT: General seq=$sequence, gpsTs=$gpsTimestamp, backendLat=$latency ms');
      }

      _flushBuffers();
      return true;
    } on TimeoutException catch (_) {
      print('General Location Sync Timeout');
      if (latitude != null) _bufferGeneralLocation(isOnline, latitude, longitude, heading, speed, accuracy, gpsTimestamp, sequence);
      return false;
    } catch (e) {
      print('General Location Sync Error: $e');
      if (latitude != null) _bufferGeneralLocation(isOnline, latitude, longitude, heading, speed, accuracy, gpsTimestamp, sequence);
      return false;
    }
  }

  void _bufferGeneralLocation(bool online, double lat, double? lng, double? h, double? s, double? acc, int? ts, int? seq) {
    if (_generalLocationBuffer.length >= 60) {
      _generalLocationBuffer.removeAt(0);
    }
    _generalLocationBuffer.add({
      'isOnline': online,
      'latitude': lat,
      'longitude': lng,
      'heading': h,
      'speed': s,
      'accuracy': acc,
      'gpsTimestamp': ts ?? DateTime.now().millisecondsSinceEpoch,
      'sequence': seq,
    });
  }

  Future<void> _flushBuffers() async {
    if (_isFlushing) return;
    if (_generalLocationBuffer.isEmpty && _orderLocationBuffer.isEmpty) return;

    _isFlushing = true;
    try {
      final token = await ClerkAuthService().getValidToken();
      if (token == null) return;
      final apiUrl = await Env.getNextJsApiUrl();

      // Flush General Location Buffer (send sequentially to preserve order)
      while (_generalLocationBuffer.isNotEmpty) {
        final point = _generalLocationBuffer.first;
        final response = await http.post(
          Uri.parse('$apiUrl/driver/location/general'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Bypass-Tunnel-Reminder': 'true',
          },
          body: jsonEncode(point),
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          _generalLocationBuffer.removeAt(0);
        } else {
          break; // Stop flushing on failure
        }
      }

      // Flush Order Location Buffer
      while (_orderLocationBuffer.isNotEmpty) {
        final point = _orderLocationBuffer.first;
        final response = await http.post(
          Uri.parse('$apiUrl/driver/location'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Bypass-Tunnel-Reminder': 'true',
          },
          body: jsonEncode(point),
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          _orderLocationBuffer.removeAt(0);
        } else {
          break;
        }
      }
    } catch (e) {
      print('Buffer Flush Error: $e');
    } finally {
      _isFlushing = false;
    }
  }

  Future<Map<String, dynamic>?> getActiveAssignment() async {
    final token = await ClerkAuthService().getValidToken();
    if (token == null) return null;

    try {
      final apiUrl = await Env.getNextJsApiUrl();
      final response = await http.get(
        Uri.parse('$apiUrl/driver/assignment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['assignment'];
      }
      return null;
    } on TimeoutException catch (_) {
      print('Assignment Sync Timeout');
      return null;
    } catch (e) {
      print('Assignment Sync Error: $e');
      return null;
    }
  }
  Future<bool> registerPartner(String name, String phone) async {
    final token = await ClerkAuthService().getValidToken();
    if (token == null) return false;

    try {
      final apiUrl = await Env.getNextJsApiUrl();
      final response = await http.post(
        Uri.parse('$apiUrl/driver/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'name': name,
          'phone': phone,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException catch (_) {
      throw Exception('Connection to Backend Timed Out (15s)');
    } catch (e) {
      throw Exception('Network Error: $e');
    }
  }

  Future<bool> updateDeliveryStatus({
    required String orderId,
    required String action,
  }) async {
    final token = await ClerkAuthService().getValidToken();
    if (token == null) return false;

    try {
      final apiUrl = await Env.getNextJsApiUrl();
      final response = await http.post(
        Uri.parse('$apiUrl/driver/assignment/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'orderId': orderId,
          'action': action,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Update Status Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Update Status Network Error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final token = await ClerkAuthService().getValidToken();
    if (token == null) return [];

    try {
      final apiUrl = await Env.getNextJsApiUrl();
      final response = await http.get(
        Uri.parse('$apiUrl/driver/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['history'] != null) {
          return List<Map<String, dynamic>>.from(data['history']);
        }
      }
      return [];
    } catch (e) {
      print('History Fetch Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final token = await ClerkAuthService().getValidToken();
    if (token == null) return null;

    try {
      final apiUrl = await Env.getNextJsApiUrl();
      final response = await http.get(
        Uri.parse('$apiUrl/driver/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['profile'];
      }
      return null;
    } catch (e) {
      print('Profile Fetch Error: $e');
      return null;
    }
  }
}
