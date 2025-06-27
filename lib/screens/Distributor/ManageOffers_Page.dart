import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class ManageOffersPage extends StatefulWidget {
  const ManageOffersPage({super.key});

  @override
  State<ManageOffersPage> createState() => _ManageOffersPageState();
}

class _ManageOffersPageState extends State<ManageOffersPage> {
  List<dynamic> offers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchOffers();
  }

  Future<void> fetchOffers() async {
    final result = await ApiService.getOffers();
    setState(() {
      offers = result;
      loading = false;
    });
  }

  Future<void> deleteOffer(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final success = await ApiService.deleteOffer(token, id);

    if (success) {
      fetchOffers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Offer deleted")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to delete offer")),
      );
    }
  }

  void openAddOffer(int productId, String productName) {
    Navigator.pushNamed(context, '/addOffer', arguments: {
      'productId': productId,
      'productName': productName,
    }).then((_) => fetchOffers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Offers"),
        backgroundColor: Colors.deepPurple,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : offers.isEmpty
              ? const Center(child: Text("No offers available"))
              : ListView.builder(
                  itemCount: offers.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final offer = offers[index];
                    return Card(
                      child: ListTile(
                        title: Text(offer['product_name']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Price: \$${offer['discount_price']}"),
                            Text(
                              "Expires: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(offer['expiration_date']))}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
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
        onPressed: () async {
          // Optional: select a product to add offer for
          final selected = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (_) => _SelectProductDialog(),
          );
          if (selected != null) {
            openAddOffer(selected['id'], selected['name']);
          }
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SelectProductDialog extends StatefulWidget {
  @override
  State<_SelectProductDialog> createState() => _SelectProductDialogState();
}

class _SelectProductDialogState extends State<_SelectProductDialog> {
  List<dynamic> products = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final result = await ApiService.getProducts(token);
    setState(() {
      products = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Select Product"),
      content: loading
          ? const Center(child: CircularProgressIndicator())
          : SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  return ListTile(
                    title: Text(p['name']),
                    onTap: () => Navigator.pop(context, {
                      'id': p['id'],
                      'name': p['name'],
                    }),
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        )
      ],
    );
  }
}
