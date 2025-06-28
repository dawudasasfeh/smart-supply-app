import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<dynamic> inventory = [];
  bool isLoading = true;
  String token = '';

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

 void _predictAndRestock(int productId, String name) async {
  print('Predicting restock for product $productId');
  final quantity = await ApiService.predictRestock(productId: productId, daysAhead: 7);
  print('Prediction result: $quantity');

  if (quantity == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to get restock prediction")),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text("AI Suggestion for '$name'"),
      content: Text("Restock $quantity units?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            final success = await ApiService.restockProduct(productId, quantity);
            Navigator.pop(context);
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Product restocked successfully")),
              );
              fetchInventory(); // Or fetchProducts(), whatever refreshes the page
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
                        trailing: IconButton(
                          icon: const Icon(Icons.insights, color: Colors.teal),
                          tooltip: 'Predict Restock',
                          onPressed: () => _predictAndRestock(item['product_id'] ?? item['id'], item['product_name'] ?? item['name'] ?? 'Product'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
