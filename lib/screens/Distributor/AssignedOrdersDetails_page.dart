import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AssignedOrdersDetailsPage extends StatefulWidget {
  final int deliveryId;

  const AssignedOrdersDetailsPage({super.key, required this.deliveryId});

  @override
  State<AssignedOrdersDetailsPage> createState() => _AssignedOrdersDetailsPageState();
}

class _AssignedOrdersDetailsPageState extends State<AssignedOrdersDetailsPage> {
  List<dynamic> assignedOrders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAssignedOrders();
  }

  Future<void> fetchAssignedOrders() async {
    try {
      final result = await ApiService.getAssignedOrders(widget.deliveryId);
      setState(() {
        assignedOrders = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load assigned orders: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery Assignments"),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : assignedOrders.isEmpty
              ? const Center(child: Text("No orders assigned to this delivery person"))
              : ListView.builder(
                  itemCount: assignedOrders.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final order = assignedOrders[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.inventory),
                        title: Text("Order #${order['id']}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Qty: ${order['quantity']}"),
                            Text("Status: ${order['status']}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
