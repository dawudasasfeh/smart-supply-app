import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../cartmanager_page.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  List<dynamic> offers = [];

  @override
  void initState() {
    super.initState();
    fetchOffers();
  }

  Future<void> fetchOffers() async {
    final result = await ApiService.getOffers();
    setState(() => offers = result);
  }

  void addToCart(Map<String, dynamic> offer) {
    final cartItem = {
      'id': offer['product_id'],
      'name': offer['product_name'],
      'price': offer['discount_price'],
      'distributor_id': offer['distributor_id'],
      'quantity': 1,
    };

    CartManager().addItem(cartItem);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${offer['product_name']} added to cart")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Special Offers"), backgroundColor: Colors.deepPurple),
      body: offers.isEmpty
          ? const Center(child: Text("No offers available"))
          : ListView.builder(
              itemCount: offers.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final offer = offers[index];
                return Card(
                  child: ListTile(
                    title: Text(offer['product_name']),
                    subtitle: Text("Discount: \$${offer['discount_price']}\nExpires: ${offer['expiration_date'] ?? 'N/A'}"),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.add_shopping_cart, color: Colors.deepPurple),
                      onPressed: () => addToCart(offer),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
