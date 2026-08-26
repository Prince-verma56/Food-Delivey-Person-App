import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../storage/token_storage.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final String? errorCode;
  final String? token;

  AuthResult({required this.success, this.errorMessage, this.errorCode, this.token});
}

class ClerkAuthService {
  static final ClerkAuthService _instance = ClerkAuthService._internal();
  factory ClerkAuthService() => _instance;
  ClerkAuthService._internal();

  String? _sessionId;
  String? _clientJwt;
  String? _signInId;
  
  // Initialize by loading session from storage
  Future<void> initialize() async {
    _sessionId = await TokenStorage.getSessionId();
    _clientJwt = await TokenStorage.getClientJwt();
  }

  // Helper method to make Clerk HTTP POST requests and intercept the client JWT
  Future<http.Response> _post(String path, {Object? body, Map<String, String>? extraHeaders}) async {
    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      ...?extraHeaders,
    };
    
    if (_clientJwt != null) {
      headers['Authorization'] = _clientJwt!;
    }
    
    final res = await http.post(
      Uri.parse('${Env.clerkFapiUrl}$path'),
      headers: headers,
      body: body,
    );
    
    // Clerk returns the client JWT in the 'authorization' header
    if (res.headers.containsKey('authorization')) {
      _clientJwt = res.headers['authorization'];
      if (_clientJwt != null) {
        await TokenStorage.saveClientJwt(_clientJwt!);
      }
    }
    
    return res;
  }

  String? _cachedToken;
  DateTime? _tokenExpiry;

  // Check if session exists and get a fresh token
  Future<String?> getValidToken() async {
    await initialize();
    if (_sessionId == null) return null;
    
    if (_cachedToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }
    
    return await getToken();
  }

  // Login with Email and Password using Clerk Frontend API
  Future<AuthResult> login(String email, String password) async {
    try {
      if (_sessionId != null) {
        await logout(); // Clear existing broken session
      }

      // 1. Create a Sign In
      final signInRes = await _post('/client/sign_ins', body: {
        'identifier': email,
      });
      
      if (signInRes.statusCode != 200) {
        final errorData = jsonDecode(signInRes.body);
        final errorMessage = errorData['errors']?[0]?['message'] ?? 'Sign in failed';
        final errorCode = errorData['errors']?[0]?['code'];
        print('Sign In Error: ${signInRes.body}');
        return AuthResult(success: false, errorMessage: errorMessage, errorCode: errorCode);
      }
      
      final signInData = jsonDecode(signInRes.body);
      final signInId = signInData['response']['id'];

      // 2. Attempt First Factor (Password)
      final attemptRes = await _post('/client/sign_ins/$signInId/attempt_first_factor', body: {
        'strategy': 'password',
        'password': password,
      });

      if (attemptRes.statusCode != 200) {
        final errorData = jsonDecode(attemptRes.body);
        final errorMessage = errorData['errors']?[0]?['message'] ?? 'Incorrect password';
        final errorCode = errorData['errors']?[0]?['code'];
        print('Attempt Error: ${attemptRes.body}');
        return AuthResult(success: false, errorMessage: errorMessage, errorCode: errorCode);
      }

      final attemptData = jsonDecode(attemptRes.body);
      final actualStatus = attemptData['response']['status'];
      
      if (actualStatus == 'complete') {
        _sessionId = attemptData['response']['created_session_id'];
        await TokenStorage.saveSessionId(_sessionId!);
        
        // 3. Get JWT Token for the session
        final token = await getToken();
        if (token != null) {
          await TokenStorage.saveToken(token);
          return AuthResult(success: true, token: token);
        } else {
          return AuthResult(success: false, errorMessage: 'Failed to retrieve session token');
        }
      } else if (actualStatus == 'needs_second_factor') {
        _signInId = attemptData['response']['id'];
        
        final prepareRes = await _post('/client/sign_ins/$_signInId/prepare_second_factor', body: {
          'strategy': 'email_code',
        });
        
        if (prepareRes.statusCode == 200) {
          return AuthResult(success: false, errorMessage: 'Verification code sent', errorCode: 'needs_second_factor');
        } else {
          return AuthResult(success: false, errorMessage: 'Failed to send verification code');
        }
      }
      
      print('Sign in incomplete. Status: $actualStatus');
      return AuthResult(success: false, errorMessage: 'Sign in incomplete: $actualStatus');
    } catch (e) {
      print('Login Exception: $e');
      return AuthResult(success: false, errorMessage: 'Network error: Could not reach authentication server.');
    }
  }

  Future<String?> getToken() async {
    if (_sessionId == null) return null;
    try {
      final tokenRes = await _post('/client/sessions/$_sessionId/tokens/convex', extraHeaders: {
        'Content-Type': 'application/json',
      });
      
      if (tokenRes.statusCode == 200) {
        final tokenData = jsonDecode(tokenRes.body);
        final token = tokenData['jwt'];
        await TokenStorage.saveToken(token);
        _cachedToken = token;
        _tokenExpiry = DateTime.now().add(const Duration(seconds: 50));
        return token;
      }
      // If session is expired/invalid, clear local storage
      if (tokenRes.statusCode == 404 || tokenRes.statusCode == 401) {
        await logout();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String? _signUpId;

  // 1. Sign Up and Send OTP
  Future<AuthResult> signUp(String email, String password) async {
    try {
      final signUpRes = await _post('/client/sign_ups', body: {
        'email_address': email,
        'password': password,
      });

      if (signUpRes.statusCode != 200) {
        final errorData = jsonDecode(signUpRes.body);
        final errorMessage = errorData['errors']?[0]?['message'] ?? 'Sign up failed';
        final errorCode = errorData['errors']?[0]?['code'];
        print('Sign Up Error: ${signUpRes.body}');
        return AuthResult(success: false, errorMessage: errorMessage, errorCode: errorCode);
      }

      final signUpData = jsonDecode(signUpRes.body);
      _signUpId = signUpData['response']['id'];

      if (_signUpId == null) return AuthResult(success: false, errorMessage: 'Failed to retrieve signup ID');

      // Prepare verification (Send Email Code)
      final prepareRes = await _post('/client/sign_ups/$_signUpId/prepare_verification', body: {
        'strategy': 'email_code',
      });

      if (prepareRes.statusCode != 200) {
        final errorData = jsonDecode(prepareRes.body);
        final errorMessage = errorData['errors']?[0]?['message'] ?? 'Prepare verification failed';
        final errorCode = errorData['errors']?[0]?['code'];
        print('Prepare Verification Error: ${prepareRes.body}');
        return AuthResult(success: false, errorMessage: errorMessage, errorCode: errorCode);
      }

      return AuthResult(success: true); // OTP sent successfully
    } catch (e) {
      print('Sign Up Exception: $e');
      return AuthResult(success: false, errorMessage: 'Network error: Could not reach authentication server.');
    }
  }

  // 2. Verify OTP and Get Token
  Future<AuthResult> verifyEmail(String code) async {
    if (_signUpId == null) return AuthResult(success: false, errorMessage: 'No active signup session');
    try {
      final verifyRes = await _post('/client/sign_ups/$_signUpId/attempt_verification', body: {
        'strategy': 'email_code',
        'code': code,
      });

      if (verifyRes.statusCode != 200) {
        final errorData = jsonDecode(verifyRes.body);
        final errorMessage = errorData['errors']?[0]?['message'] ?? 'Verification failed';
        final errorCode = errorData['errors']?[0]?['code'];
        print('Verify Error: ${verifyRes.body}');
        return AuthResult(success: false, errorMessage: errorMessage, errorCode: errorCode);
      }

      final verifyData = jsonDecode(verifyRes.body);
      if (verifyData['response']['status'] == 'complete') {
        _sessionId = verifyData['response']['created_session_id'];
        await TokenStorage.saveSessionId(_sessionId!);
        
        final token = await getToken();
        if (token != null) {
          await TokenStorage.saveToken(token);
          return AuthResult(success: true, token: token);
        } else {
          return AuthResult(success: false, errorMessage: 'Failed to retrieve session token');
        }
      }
      
      return AuthResult(success: false, errorMessage: 'Verification incomplete');
    } catch (e) {
      print('Verify Exception: $e');
      return AuthResult(success: false, errorMessage: 'Network error: Could not reach authentication server.');
    }
  }

  // Logout
  Future<void> logout() async {
    _sessionId = null;
    _clientJwt = null;
    _signInId = null;
    await TokenStorage.clearAll();
  }

  Future<AuthResult> verifyLoginMfa(String code) async {
    try {
      if (_signInId == null) return AuthResult(success: false, errorMessage: 'Sign in ID is missing');
      
      final verifyRes = await _post('/client/sign_ins/$_signInId/attempt_second_factor', body: {
        'strategy': 'email_code',
        'code': code,
      });

      if (verifyRes.statusCode == 200) {
        final verifyData = jsonDecode(verifyRes.body);
        if (verifyData['response']['status'] == 'complete') {
          _sessionId = verifyData['response']['created_session_id'];
          await TokenStorage.saveSessionId(_sessionId!);
          
          final token = await getToken();
          if (token != null) {
            await TokenStorage.saveToken(token);
            return AuthResult(success: true, token: token);
          } else {
            return AuthResult(success: false, errorMessage: 'Failed to retrieve session token');
          }
        }
        return AuthResult(success: false, errorMessage: 'Verification incomplete: ${verifyData['response']['status']}');
      }
      
      final errorData = jsonDecode(verifyRes.body);
      final errorMessage = errorData['errors']?[0]?['message'] ?? 'Invalid verification code';
      return AuthResult(success: false, errorMessage: errorMessage);
    } catch (e) {
      return AuthResult(success: false, errorMessage: 'Network error');
    }
  }
}
