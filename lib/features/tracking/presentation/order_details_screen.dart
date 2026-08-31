import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/location/rider_state_provider.dart';
import 'rider_map_screen.dart';
import '../../../core/networking/backend_service.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> assignment;

  const OrderDetailsScreen({super.key, required this.assignment});

  Future<void> _updateStatus(BuildContext context, String action) async {
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updating status...')));
    final success = await BackendService().updateDeliveryStatus(
      orderId: assignment['_id'],
      action: action,
    );
    if (success && context.mounted) {
      context.read<RiderStateProvider>().refreshAssignment();
      if (action == 'delivered') {
        Navigator.pop(context);
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = assignment['deliveryStatus'] ?? 'assigned';
    final orderNumber = assignment['orderNumber'] ?? assignment['_id']?.substring(0, 8);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$orderNumber'),
        backgroundColor: Colors.orange.shade400,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(status.toString().toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 16),
                    const Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text('${assignment['customer']?['name'] ?? 'Customer'}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('${assignment['customer']?['address'] ?? 'Unknown Address'}'),
                    if (assignment['customer']?['phone'] != null)
                      Text('${assignment['customer']?['phone']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RiderMapScreen(assignment: assignment),
                  ),
                );
              },
              icon: const Icon(Icons.map, color: Colors.white),
              label: const Text('OPEN LIVE TRACKING MAP', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, padding: const EdgeInsets.all(16)),
            ),
            const SizedBox(height: 24),
            const Text('Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (status == 'assigned')
              _actionButton(context, 'ACCEPT ORDER', 'accepted', Colors.green)
            else if (status == 'accepted')
              _actionButton(context, 'CONFIRM PICKUP', 'picked_up', Colors.orange)
            else if (status == 'picked_up')
              _actionButton(context, 'START DELIVERY', 'out_for_delivery', Colors.blue)
            else if (status == 'out_for_delivery' || status == 'on_the_way')
              _actionButton(context, 'MARK AS DELIVERED', 'delivered', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, String label, String action, Color color) {
    return ElevatedButton(
      onPressed: () => _updateStatus(context, action),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}
