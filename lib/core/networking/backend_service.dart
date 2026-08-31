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
      return true;
    } on TimeoutException catch (_) {
      print('Location Sync Timeout');
      updatesFailed++;
      return false;
    } catch (e) {
      print('Location Sync Error: $e');
      updatesFailed++;
      return false;
    }
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

      return true;
    } on TimeoutException catch (_) {
      print('General Location Sync Timeout');
      return false;
    } catch (e) {
      print('General Location Sync Error: $e');
      return false;
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
}
