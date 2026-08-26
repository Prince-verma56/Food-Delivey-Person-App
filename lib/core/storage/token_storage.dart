import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _keyToken = 'clerk_jwt_token';
  static const String _keySessionId = 'clerk_session_id';
  static const String _keyClientJwt = 'clerk_client_jwt';

  // Save the token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  // Get the token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // Save the session ID
  static Future<void> saveSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionId, sessionId);
  }

  // Get the session ID
  static Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySessionId);
  }
  

  // Save the client JWT
  static Future<void> saveClientJwt(String clientJwt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyClientJwt, clientJwt);
  }

  // Get the client JWT
  static Future<String?> getClientJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyClientJwt);
  }

  // Clear all data (Logout)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keySessionId);
    await prefs.remove(_keyClientJwt);
  }
}




