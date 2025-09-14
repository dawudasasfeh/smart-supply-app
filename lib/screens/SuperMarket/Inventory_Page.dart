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

void _predictAndRestock(dynamic item) async {
  final productId = item['product_id'] ?? item['id'];
  final productName = item['product_name'] ?? item['name'] ?? 'Product';

  // Parse stockLevel safely to double
  double stockLevel = 0;
  final stockValue = item['total_quantity'] ?? item['stock'] ?? 0;
  if (stockValue is String) {
    stockLevel = double.tryParse(stockValue) ?? 0;
  } else if (stockValue is int) {
    stockLevel = stockValue.toDouble();
  } else if (stockValue is double) {
    stockLevel = stockValue;
  }

  // Same for previousOrders & activeOffers - parse as int
  int previousOrders = 0;
  final prevOrdersValue = item['previous_orders'] ?? 0;
  if (prevOrdersValue is String) {
    previousOrders = int.tryParse(prevOrdersValue) ?? 0;
  } else if (prevOrdersValue is int) {
    previousOrders = prevOrdersValue;
  }

  int activeOffers = 0;
  final activeOffersValue = item['active_offers'] ?? 0;
  if (activeOffersValue is String) {
    activeOffers = int.tryParse(activeOffersValue) ?? 0;
  } else if (activeOffersValue is int) {
    activeOffers = activeOffersValue;
  }

  final distributorId = item['distributor_id'] ?? 1;
  final date = DateTime.now().toIso8601String().split('T').first;

  print(
    'Calling predictRestock with: productId=$productId, distributorId=$distributorId, stockLevel=$stockLevel, previousOrders=$previousOrders, activeOffers=$activeOffers, date=$date'
  );

  try {
    final prediction = await ApiService.predictRestock(
      productId: productId,
      distributorId: distributorId,
      stockLevel: stockLevel,
      previousOrders: previousOrders,
      activeOffers: activeOffers,
      date: date,
    );

    if (prediction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to get restock prediction")),
      );
      return;
    }

    final suggestedQuantity = prediction['suggested_quantity'] ?? 0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("AI Suggestion for '$productName'"),
        content: Text("Restock $suggestedQuantity units?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final success = await ApiService.restockProduct(token, productId, suggestedQuantity);
              Navigator.pop(context);
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
    print('Error during restock prediction: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: ${e.toString()}")),
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
                        subtitle: Text("Stock: ${item['total_quantity'] ?? item['stock'] ?? 0}"),
                        trailing: IconButton(
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
