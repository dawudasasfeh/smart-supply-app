import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class DeliveryManagementPage extends StatefulWidget {
  const DeliveryManagementPage({super.key});

  @override
  State<DeliveryManagementPage> createState() => _DeliveryManagementPageState();
}

class _DeliveryManagementPageState extends State<DeliveryManagementPage> {
  List<Map<String, dynamic>> deliveryMen = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDeliveryMen();
  }

  Future<void> fetchDeliveryMen() async {
    try {
      final result = await ApiService.getUsersByRole('delivery');
      setState(() {
        deliveryMen = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch delivery personnel")),
      );
    }
  }

  void openAssignedOrders(int deliveryId) {
    Navigator.pushNamed(
      context,
      '/assignedOrdersDetails',
      arguments: deliveryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery Management"),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : deliveryMen.isEmpty
              ? const Center(child: Text("No delivery personnel found."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: deliveryMen.length,
                  itemBuilder: (context, index) {
                    final user = deliveryMen[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.delivery_dining, color: Colors.deepPurple),
                        title: Text(user['name']),
                        subtitle: Text("ID: ${user['id']}"),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => openAssignedOrders(user['id']),
                      ),
                    );
                  },
                ),
    );
  }
}
