import 'package:flutter/material.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  final List<Map<String, dynamic>> mockInventory = const [
    {'product': 'Milk', 'stock': 12},
    {'product': 'Rice', 'stock': 3},
    {'product': 'Bread', 'stock': 8},
    {'product': 'Tomato Sauce', 'stock': 0},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: Colors.grey[100],
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mockInventory.length,
        itemBuilder: (context, index) {
          final item = mockInventory[index];
          final isLowStock = item['stock'] <= 5;

          return Card(
            color: isLowStock ? Colors.red[50] : Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: Colors.deepPurple),
              title: Text(item['product'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("In Stock: ${item['stock']}"),
              trailing: isLowStock
                  ? const Icon(Icons.warning_amber, color: Colors.red)
                  : const Icon(Icons.check_circle, color: Colors.green),
              onTap: () {
                // Optional: Show restock history or forecast
              },
            ),
          );
        },
      ),
    );
  }
}
