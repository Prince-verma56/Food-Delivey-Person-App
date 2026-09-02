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

  // ---------------------------------------------------------
  // MULTI-TENANCY CONFIGURATION
  // ---------------------------------------------------------
  
  // The restaurant ID this app instance is built for. 
  // In a true white-label flow, this would be set via --dart-define at build time.
  static const String restaurantId = String.fromEnvironment(
    'RESTAURANT_ID',
    defaultValue: 'jx71m7g7s0p08nqg36d8mmsym570bksn', // Default to Dev Tarka Pizza for dev
  );
}
