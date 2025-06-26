import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class AssignedOrdersPage extends StatefulWidget {
  const AssignedOrdersPage({Key? key}) : super(key: key);

  @override
  State<AssignedOrdersPage> createState() => _AssignedOrdersPageState();
}

class _AssignedOrdersPageState extends State<AssignedOrdersPage> {
  List<dynamic> assignedOrders = [];
  int? deliveryId;

  @override
  void initState() {
    super.initState();
    loadDeliveryIdAndFetch();
  }

  Future<void> loadDeliveryIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    deliveryId = prefs.getInt('user_id');
    if (deliveryId != null) {
      fetchAssignedOrders();
    } else {
      debugPrint("⚠️ deliveryId not found in SharedPreferences");
    }
  }

  Future<void> fetchAssignedOrders() async {
    if (deliveryId == null) return;
    final orders = await ApiService.getAssignedOrders(deliveryId!);
    setState(() => assignedOrders = orders);
  }

  Future<void> markDelivered(int orderId) async {
    if (deliveryId == null) return;
    final success = await ApiService.updateDeliveryStatus(
      orderId: orderId,
      deliveryId: deliveryId!,
      status: 'delivered',
    );
    if (success) {
      fetchAssignedOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update status")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assigned Orders"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.pushNamed(context, '/qrScan'),
          ),
        ],
      ),
      body: assignedOrders.isEmpty
          ? const Center(child: Text("No assigned orders yet"))
          : ListView.builder(
              itemCount: assignedOrders.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final order = assignedOrders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text("Order #${order['id']}"),
                    subtitle: Text("Status: ${order['delivery_status'] ?? order['status']}"),
                    trailing: ElevatedButton(
                      onPressed: () => markDelivered(order['id']),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("Mark Delivered"),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
