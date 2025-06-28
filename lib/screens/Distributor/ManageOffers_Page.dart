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

  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    fetchMyOffers();
  }

  Future<void> fetchMyOffers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final result = await ApiService.getMyOffers(token);
    setState(() => offers = result);
  }

  Future<void> deleteOffer(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    await ApiService.deleteOffer(token, id);
    fetchMyOffers();
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
                    title: Text(offer['product_name'] ?? 'Unnamed'),  // product_name now comes from backend join
                    subtitle: Text(
                      "Price: \$${offer['discount_price']} | Expires: ${formatDate(offer['expiration_date'])}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteOffer(offer['id']),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: () => Navigator.pushNamed(context, '/manageProducts').then((_) => fetchMyOffers()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
