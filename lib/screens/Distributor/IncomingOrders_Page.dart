import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class SupplierOrdersPage extends StatefulWidget {
  const SupplierOrdersPage({super.key});

  @override
  State<SupplierOrdersPage> createState() => _SupplierOrdersPageState();
}

class _SupplierOrdersPageState extends State<SupplierOrdersPage> {
  List<dynamic> orders = [];
  List<Map<String, dynamic>> deliveryMen = [];
  int? selectedDeliveryId;
  int? assigningOrderId;

  @override
  void initState() {
    super.initState();
    fetchOrders();
    fetchDeliveryMen();
  }

 Future<void> fetchOrders() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token') ?? '';
  final distributorId = prefs.getInt('user_id'); // or your distributor ID key
  final result = await ApiService.getDistributorOrders(token, distributorId!);
  print('Fetched orders: $result');
  setState(() => orders = result);
}

  Future<void> fetchDeliveryMen() async {
  try {
    final result = await ApiService.getAvailableDeliveryMen();
    setState(() => deliveryMen = result);
  } catch (e) {
    setState(() => deliveryMen = []);
    debugPrint("❌ Failed to fetch delivery men: $e");
  }
}


  Future<void> updateStatus(int id, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    await ApiService.updateOrderStatus(token, id, status);
    fetchOrders();
  }

  Future<void> assignToDeliveryMan(int orderId, int deliveryId) async {
    final success = await ApiService.assignOrderToDelivery(orderId, deliveryId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Assigned to delivery man")),
      );
      setState(() {
        assigningOrderId = null;
        selectedDeliveryId = null;
      });
      fetchOrders(); // refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Incoming Orders"), backgroundColor: Colors.deepPurple),
      body: orders.isEmpty
          ? const Center(child: Text("No incoming orders"))
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final isAssigning = assigningOrderId == order['id'];
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text("Order #${order['id']}"),
                        subtitle: Text("Qty: ${order['quantity']} | Status: ${order['status']}"),
                        trailing: order['status'] == 'Pending'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () async {
                                      await updateStatus(order['id'], 'Accepted');
                                      setState(() => assigningOrderId = order['id']);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => updateStatus(order['id'], 'Rejected'),
                                  ),
                                ],
                              )
                            : Text(order['status']),
                      ),
                      if (isAssigning)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Select Delivery Man"),
                              const SizedBox(height: 8),
                              DropdownButton<int>(
                              hint: const Text("Select Delivery Man"),
                              value: selectedDeliveryId,
                              items: deliveryMen.map((man) {
                                return DropdownMenuItem<int>(
                                  value: man['id'],
                                  child: Text(man['name']),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => selectedDeliveryId = val),
                            ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: selectedDeliveryId != null
                                      ? () => assignToDeliveryMan(order['id'], selectedDeliveryId!)
                                      : null,
                                  child: const Text("Assign"),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
