import 'package:flutter/material.dart';
import '../../../core/authentication/clerk_auth_service.dart';
import 'otp_screen.dart';

import '../../diagnostic/presentation/diagnostic_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _signup() async {
    setState(() => _isLoading = true);
    
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters long')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final authResult = await ClerkAuthService().signUp(email, password);
    
    setState(() => _isLoading = false);

    if (authResult.success) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(name: name, phone: phone)),
      );
    } else {
      if (!mounted) return;
      
      String displayError = authResult.errorMessage ?? 'Sign up failed';
      if (displayError.toLowerCase().contains('taken')) {
        displayError = 'This email is already registered. Please sign in instead.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(displayError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DT Pizza Rider Sign Up'),
        backgroundColor: Colors.orange.shade400,
        actions: [
          IconButton(
            icon: const Icon(Icons.monitor_heart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiagnosticScreen()),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_add_alt_1, size: 80, color: Colors.orange),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _signup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('SIGN UP', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Already have an account? Login here', style: TextStyle(color: Colors.orange)),
            )
          ],
        ),
      ),
    );
  }
}
