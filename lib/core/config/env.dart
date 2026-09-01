import 'package:shared_preferences/shared_preferences.dart';

class Env {
  // ---------------------------------------------------------
  // PUBLIC / SAFE FOR MOBILE CONFIGURATION
  // ---------------------------------------------------------

  // Clerk Frontend API for authentication
  static const String clerkFapiUrl = String.fromEnvironment(
    'CLERK_FRONTEND_API',
    defaultValue: 'https://giving-rabbit-9615.clerk.accounts.dev/v1',
  );

  // Mapbox Token (Public)
  static const String mapBoxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  // Convex HTTP API Bridge (Publicly accessible from anywhere)
  static const String defaultNextJsApiUrl = String.fromEnvironment(
    'CONVEX_HTTP_URL',
    defaultValue: 'https://veracious-duck-472.convex.site/api',
  ); 
  
  static Future<String> getNextJsApiUrl() async {
    // We now always return the stable Convex Cloud HTTP URL (configurable via --dart-define)
    return defaultNextJsApiUrl;
  }
}
