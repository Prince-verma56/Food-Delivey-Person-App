import 'package:shared_preferences/shared_preferences.dart';

class Env {
  // ---------------------------------------------------------
  // PUBLIC / SAFE FOR MOBILE CONFIGURATION
  // ---------------------------------------------------------

  // Clerk Frontend API for authentication
  static const String clerkFapiUrl = 'https://giving-rabbit-9615.clerk.accounts.dev/v1';

  // Mapbox Token (Public)
  static const String mapBoxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  // Convex HTTP API Bridge (Publicly accessible from anywhere)
  // Replaced local Next.js API with direct Convex HTTP endpoints
  static const String defaultNextJsApiUrl = 'https://veracious-duck-472.convex.site/api'; 
  
  static Future<String> getNextJsApiUrl() async {
    // We now always return the stable Convex Cloud HTTP URL.
    // Local IP overrides are no longer necessary since this is globally accessible.
    return defaultNextJsApiUrl;
  }
}
