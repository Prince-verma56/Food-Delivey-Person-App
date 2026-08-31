import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/location/rider_state_provider.dart';
import '../../tracking/presentation/order_details_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _getTimeAgo(DateTime? lastSync) {
    if (lastSync == null) return "Never";
    final diff = DateTime.now().difference(lastSync);
    if (diff.inSeconds < 60) return "${diff.inSeconds} sec ago";
    return "${diff.inMinutes} min ago";
  }

  @override
  Widget build(BuildContext context) {
    final riderState = context.watch<RiderStateProvider>();
    final assignment = riderState.assignment;
    final isOnline = riderState.isOnline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.orange.shade400,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => riderState.refreshAssignment(),
          ),
        ],
      ),
      body: riderState.isLoadingAssignment
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Hello 👋',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Online/Offline Control
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isOnline ? Colors.green.shade200 : Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.circle, color: isOnline ? Colors.green : Colors.grey, size: 16),
                              const SizedBox(width: 8),
                              Text('Status: ${isOnline ? 'Online' : 'Offline'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Switch(
                            value: isOnline,
                            onChanged: (_) => riderState.toggleOnlineStatus(context),
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                      if (isOnline) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Network:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(riderState.isNetworkConnected ? 'Connected' : 'Offline', style: TextStyle(color: riderState.isNetworkConnected ? Colors.green : Colors.red)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Telemetry:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(riderState.gpsStatusText, style: TextStyle(color: riderState.gpsStatusText == 'Live' ? Colors.green : Colors.orange)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Last upload:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(_getTimeAgo(riderState.lastSync)),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                if (assignment == null)
                  const Expanded(
                    child: Center(
                      child: Text(
                        "No active delivery\nYou're ready for orders.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  )
                else ...[
                  const Text('Active Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ORDER #${assignment['orderNumber'] ?? assignment['_id']?.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 8),
                          Text('Pickup: ${assignment['restaurant']?['name'] ?? 'Restaurant'}'),
                          Text('Deliver to: ${assignment['customer']?['address'] ?? 'Customer Address'}'),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderDetailsScreen(assignment: assignment),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              child: const Text('VIEW DELIVERY', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],

                const SizedBox(height: 24),
                // Today's Summary (Static for now)
                const Text("Today's Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _summaryStat('Completed', '0'),
                    _summaryStat('Earnings', '₹0'),
                    _summaryStat('Distance', '0 km'),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
