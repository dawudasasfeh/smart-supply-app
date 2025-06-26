import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class ManageOffersPage extends StatefulWidget {
  const ManageOffersPage({super.key});

  @override
  State<ManageOffersPage> createState() => _ManageOffersPageState();
}

class _ManageOffersPageState extends State<ManageOffersPage> {
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

  void deleteOffer(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    await ApiService.deleteOffer(token, id);
    fetchOffers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Offers"), backgroundColor: Colors.deepPurple),
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
                    subtitle: Text("Discount Price: \$${offer['discount_price']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteOffer(offer['id']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
