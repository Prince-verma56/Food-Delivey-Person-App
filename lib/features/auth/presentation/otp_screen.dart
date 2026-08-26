import 'package:flutter/material.dart';
import '../../../core/authentication/clerk_auth_service.dart';
import '../../../core/networking/backend_service.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class OtpScreen extends StatefulWidget {
  final String name;
  final String phone;
  final bool isLoginMfa;

  const OtpScreen({super.key, required this.name, required this.phone, this.isLoginMfa = false});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  void _verify() async {
    setState(() => _isLoading = true);
    
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the verification code.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final authResult = widget.isLoginMfa 
        ? await ClerkAuthService().verifyLoginMfa(code)
        : await ClerkAuthService().verifyEmail(code);

    if (authResult.success && authResult.token != null) {
      
      if (widget.isLoginMfa) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
        return;
      }

      try {
        final registered = await BackendService().registerPartner(widget.name, widget.phone);
        
        setState(() => _isLoading = false);

        if (registered) {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backend Registration Failed: $e'), duration: const Duration(seconds: 10)),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authResult.errorMessage ?? 'Invalid code. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: Colors.orange.shade400,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mark_email_read, size: 80, color: Colors.orange),
            const SizedBox(height: 32),
            const Text(
              'A verification code has been sent to your email. Please enter it below.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '6-Digit Code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('VERIFY & CONTINUE', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
