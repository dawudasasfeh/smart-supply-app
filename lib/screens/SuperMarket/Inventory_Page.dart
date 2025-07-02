import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart'; // For date formatting

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<dynamic> inventory = [];
  bool isLoading = true;
  String token = '';
  bool isPredicting = false;

  @override
  void initState() {
    super.initState();
    fetchInventory();
  }

  Future<void> fetchInventory() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? '';
    final data = await ApiService.getSupermarketInventory(token);
    setState(() {
      inventory = data;
      isLoading = false;
    });
  }

  Future<void> _predictAndRestock(dynamic item) async {
    setState(() {
      isPredicting = true;
    });

    try {
      // Extract all required fields from the item
      final productId = item['product_id'] ?? item['id'];
      final distributorId = item['distributor_id'] ?? 0; // replace 0 with valid id if possible
      final stockLevel = (item['total_quantity'] ?? 0).toDouble();

      // For previous orders, active offers, date, you need actual data - example defaults:
      final previousOrders = item['previous_orders'] ?? 0;
      final activeOffers = item['active_offers'] ?? 0;
      final date = item['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

      print('Calling predictRestock with: productId=$productId, distributorId=$distributorId, stockLevel=$stockLevel, previousOrders=$previousOrders, activeOffers=$activeOffers, date=$date');

      final prediction = await ApiService.predictRestock(
        productId: productId,
        distributorId: distributorId,
        stockLevel: stockLevel,
        previousOrders: previousOrders,
        activeOffers: activeOffers,
        date: date,
      );

      setState(() {
        isPredicting = false;
      });

      if (prediction == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to get restock prediction")),
        );
        return;
      }

      final predictedDemand = (prediction['predicted_demand'] ?? 0).toDouble();

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("AI Suggestion for '${item['product_name'] ?? item['name'] ?? 'Product'}'"),
          content: Text("Predicted demand is $predictedDemand units.\nDo you want to restock this amount?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final success = await ApiService.restockProduct(productId, predictedDemand.toInt());
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Product restocked successfully")),
                  );
                  fetchInventory();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to restock product")),
                  );
                }
              },
              child: const Text("Restock Now"),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        isPredicting = false;
      });
      print('Error during restock prediction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Delivered Inventory"),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : inventory.isEmpty
              ? const Center(child: Text("No delivered inventory yet."))
              : ListView.builder(
                  itemCount: inventory.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final item = inventory[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: const Icon(Icons.inventory_2, color: Colors.deepPurple),
                        title: Text(
                          item['product_name'] ?? item['name'] ?? 'Unknown Product',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Stock: ${item['total_quantity']}"),
                        trailing: isPredicting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.insights, color: Colors.teal),
                                tooltip: 'Predict Restock',
                                onPressed: () => _predictAndRestock(item),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
