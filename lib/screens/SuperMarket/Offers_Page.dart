import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../cartmanager_page.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  List<dynamic> offers = [];
  List<Map<String, dynamic>> distributors = [];
  int? selectedDistributorId;

  @override
  void initState() {
    super.initState();
    fetchDistributorsAndOffers();
  }

  Future<void> fetchDistributorsAndOffers() async {
    final distResult = await ApiService.getAllDistributors();
    setState(() => distributors = distResult);
    await fetchOffers(); // get all offers initially
  }

  Future<void> fetchOffers() async {
    List<dynamic> fetchedOffers;

    if (selectedDistributorId == null) {
      fetchedOffers = await ApiService.getOffers(); // all offers
    } else {
      fetchedOffers = await ApiService.getOffersByDistributor(selectedDistributorId!);
    }

    setState(() => offers = fetchedOffers);
  }

  bool isExpiringSoon(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return date.difference(DateTime.now()).inDays <= 3;
    } catch (_) {
      return false;
    }
  }

  void addToCart(Map<String, dynamic> offer) {
    CartManager().addItem({
      'id': offer['product_id'],
      'name': offer['product_name'],
      'price': offer['discount_price'],
      'quantity': 1,
      'distributor_id': offer['distributor_id'],
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${offer['product_name']} added to cart")),
    );
  }

  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Special Offers"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButton<int?>(
              isExpanded: true,
              hint: const Text("Filter by Distributor"),
              value: selectedDistributorId,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text("All Distributors"),
                ),
                ...distributors.map((d) => DropdownMenuItem<int?>(
                      value: d['id'],
                      child: Text(d['name']),
                    ))
              ],
              onChanged: (val) {
                setState(() => selectedDistributorId = val);
                fetchOffers(); // re-fetch based on selection
              },
            ),
          ),
          Expanded(
            child: offers.isEmpty
                ? const Center(child: Text("No matching offers"))
                : ListView.builder(
                    itemCount: offers.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final offer = offers[index];
                      final isSoon = isExpiringSoon(offer['expiration_date']);
                      return Card(
                        child: ListTile(
                          title: Text(offer['product_name']),
                          subtitle: Text(
                            "Price: \$${offer['discount_price']} | Expires: ${formatDate(offer['expiration_date'])}" +
                            (isSoon ? "\n⚠️ Expiring Soon!" : ""),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_shopping_cart),
                            onPressed: () => addToCart(offer),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
