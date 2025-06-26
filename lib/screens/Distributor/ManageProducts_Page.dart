import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'addoffer_page.dart';

class ManageProductsPage extends StatefulWidget {
  const ManageProductsPage({super.key});

  @override
  State<ManageProductsPage> createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  List<dynamic> products = [];

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final result = await ApiService.getProducts(token);
    setState(() => products = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Products"), backgroundColor: Colors.deepPurple),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/addProduct'),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
      body: products.isEmpty
          ? const Center(child: Text("No products added yet"))
          : ListView.builder(
              itemCount: products.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  child: ListTile(
                    title: Text(product['name']),
                    subtitle: Text("Price: \$${product['price']} | Stock: ${product['stock']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/editProduct',
                            arguments: product,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.local_offer, color: Colors.orange),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddOfferPage(
                                  productId: product['id'],
                                  productName: product['name'],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
