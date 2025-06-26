import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../cartmanager_page.dart';

class BrowseProductsPage extends StatefulWidget {
  const BrowseProductsPage({super.key});

  @override
  State<BrowseProductsPage> createState() => _BrowseProductsPageState();
}

class _BrowseProductsPageState extends State<BrowseProductsPage> {
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

  void addToCart(Map<String, dynamic> product) {
    CartManager().addItem({
      'id': product['id'],
      'name': product['name'],
      'price': product['price'],
      'quantity': 1,
      'distributor_id': product['distributor_id'],
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${product['name']} added to cart")),
    );
  }

  void goToCart() {
    Navigator.pushNamed(context, '/cart');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Browse Products"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(icon: const Icon(Icons.shopping_cart), onPressed: goToCart)
        ],
      ),
      body: products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: products.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  child: ListTile(
                    title: Text(product['name']),
                    subtitle: Text("Price: \$${product['price']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_shopping_cart),
                      onPressed: () => addToCart(product),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
