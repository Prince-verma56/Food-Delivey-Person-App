import 'package:flutter/material.dart';
import '../core/authentication/clerk_auth_service.dart';
import '../core/networking/backend_service.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await ClerkAuthService().getValidToken();
    if (token != null) {
      setState(() {
        _isAuthenticated = true;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    if (_isAuthenticated) {
      return const DashboardScreen();
    }

    return const LoginScreen();
  }
}


























