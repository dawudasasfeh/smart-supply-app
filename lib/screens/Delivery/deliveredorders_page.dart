import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class DeliveredOrdersPage extends StatefulWidget {
  const DeliveredOrdersPage({super.key});

  @override
  State<DeliveredOrdersPage> createState() => _DeliveredOrdersPageState();
}

class _DeliveredOrdersPageState extends State<DeliveredOrdersPage> {
  List<dynamic> deliveredOrders = [];
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
      fetchDeliveredOrders();
    }
  }

  Future<void> fetchDeliveredOrders() async {
    if (deliveryId == null) return;
    final all = await ApiService.getAssignedOrders(deliveryId!);
    final filtered = all.where((order) => order['status'] == 'delivered').toList();
    setState(() => deliveredOrders = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivered Orders"),
        backgroundColor: Colors.green,
      ),
      body: deliveredOrders.isEmpty
          ? const Center(child: Text("No delivered orders"))
          : ListView.builder(
              itemCount: deliveredOrders.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final order = deliveredOrders[index];
                return Card(
                  child: ListTile(
                    title: Text("Order #${order['id']}"),
                    subtitle: Text("Status: Delivered"),
                  ),
                );
              },
            ),
    );
  }
}
