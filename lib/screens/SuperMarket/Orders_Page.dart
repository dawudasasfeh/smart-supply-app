import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<dynamic> orders = [];

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final result = await ApiService.getBuyerOrders(token);
    setState(() => orders = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Orders"),
        backgroundColor: Colors.deepPurple,
      ),
      body: orders.isEmpty
          ? const Center(child: Text("No orders yet"))
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text('Order #${order['id']}'),
                    subtitle: Text('Status: ${order['status']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.qr_code),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/qrGenerate',
                          arguments: {
                            'orderId': order['id'],
                            'deliveryCode': order['delivery_code'],
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
