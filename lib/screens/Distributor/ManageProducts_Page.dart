import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class ManageProductsPage extends StatefulWidget {
  const ManageProductsPage({super.key});

  @override
  State<ManageProductsPage> createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  List<dynamic> myProducts = [];
  String token = '';

  @override
  void initState() {
    super.initState();
    fetchMyProducts();
  }

  Future<void> fetchMyProducts() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? '';
    final allProducts = await ApiService.getProducts(token);
    final userId = prefs.getInt('user_id');

    setState(() {
      myProducts = allProducts.where((p) => p['distributor_id'] == userId).toList();
    });
  }

  void deleteProduct(int id) async {
    final success = await ApiService.deleteProduct(token, id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted')),
      );
      fetchMyProducts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete product')),
      );
    }
  }

  void goToEdit(Map<String, dynamic> product) {
    Navigator.pushNamed(context, '/editProduct', arguments: product).then((_) => fetchMyProducts());
  }

  void goToAddOffer(Map<String, dynamic> product) {
    Navigator.pushNamed(context, '/addOffer', arguments: {
      'productId': product['id'],
      'productName': product['name'],
    });
  }

  void goToAddProduct() {
    Navigator.pushNamed(context, '/addProduct').then((_) => fetchMyProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage My Products"),
        backgroundColor: Colors.deepPurple,
      ),
      body: myProducts.isEmpty
          ? const Center(child: Text("You haven't added any products yet."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myProducts.length,
              itemBuilder: (context, index) {
                final product = myProducts[index];
                return Card(
                  child: ListTile(
                    title: Text(product['name']),
                    subtitle: Text("Price: \$${product['price']} | Stock: ${product['stock']}"),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          goToEdit(product);
                        } else if (value == 'offer') {
                          goToAddOffer(product);
                        } else if (value == 'delete') {
                          deleteProduct(product['id']);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text("Edit")),
                        const PopupMenuItem(value: 'offer', child: Text("Make Offer")),
                        const PopupMenuItem(value: 'delete', child: Text("Delete")),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: goToAddProduct,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }
}
