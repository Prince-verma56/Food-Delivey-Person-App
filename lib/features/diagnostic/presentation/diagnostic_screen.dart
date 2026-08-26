import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/env.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  String _currentApiUrl = Env.defaultNextJsApiUrl;
  String _apiStatus = 'Untested';
  String _clerkStatus = 'Untested';
  String _lastError = 'None';
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadApiUrl();
  }

  Future<void> _loadApiUrl() async {
    final url = await Env.getNextJsApiUrl();
    if (mounted) {
      setState(() => _currentApiUrl = url);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _apiStatus = 'Testing...';
      _clerkStatus = 'Testing...';
      _lastError = 'None';
    });
    
    await _loadApiUrl(); // Ensure we have the latest URL before testing

    try {
      // Test Next.js API Bridge
      final apiRes = await http.get(Uri.parse('${_currentApiUrl.replaceAll('/api', '')}/api/driver/health'))
          .timeout(const Duration(seconds: 5));
      
      if (apiRes.statusCode == 200) {
        setState(() => _apiStatus = 'Connected (HTTP 200)');
      } else {
        setState(() {
          _apiStatus = 'Failed (HTTP ${apiRes.statusCode})';
          _lastError = 'Next.js API returned ${apiRes.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _apiStatus = 'Network Error / Unreachable';
        _lastError = e.toString();
      });
    }

    try {
      // Test Clerk API
      final clerkRes = await http.get(Uri.parse('${Env.clerkFapiUrl.replaceAll('/v1', '')}'))
          .timeout(const Duration(seconds: 5));
      // Clerk root might return 404, but it proves network reaches the domain.
      setState(() => _clerkStatus = 'Reachable');
    } catch (e) {
      setState(() {
        _clerkStatus = 'Unreachable';
        if (_lastError == 'None') _lastError = e.toString();
      });
    }

    setState(() => _isTesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusRow('Next.js API', _apiStatus, _currentApiUrl),
          const Divider(),
          _buildStatusRow('Clerk FAPI', _clerkStatus, Env.clerkFapiUrl),
          const Divider(),
          _buildStatusRow('Last Error', _lastError, null),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isTesting ? null : _testConnection,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.all(16),
            ),
            child: _isTesting 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Test Connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String title, String status, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(color: status.contains('Connected') || status.contains('Reachable') ? Colors.green : (status == 'Untested' ? Colors.grey : Colors.red), fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]
        ],
      ),
    );
  }
}
