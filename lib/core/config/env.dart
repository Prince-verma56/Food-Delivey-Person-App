import 'package:shared_preferences/shared_preferences.dart';

class Env {
  // ---------------------------------------------------------
  // PUBLIC / SAFE FOR MOBILE CONFIGURATION
  // ---------------------------------------------------------

  // Clerk Frontend API for authentication
  static const String clerkFapiUrl = 'https://giving-rabbit-9615.clerk.accounts.dev/v1';

  // Mapbox Token (Public)
  static const String mapBoxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  // Next.js API Bridge (Dynamic for local testing)
  // Default fallback if not set in Settings
  static const String defaultNextJsApiUrl = 'http://172.16.163.148:3000/api'; 
  
  static Future<String> getNextJsApiUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('api_url') ?? defaultNextJsApiUrl;
    } catch (e) {
      return defaultNextJsApiUrl;
    }
  }
}
