import 'package:flutter/material.dart';
import '../../services/api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Available Offers"), backgroundColor: Colors.deepPurple),
      body: offers.isEmpty
          ? const Center(child: Text("No active offers"))
          : ListView.builder(
              itemCount: offers.length,
              itemBuilder: (context, index) {
                final offer = offers[index];
                return Card(
                  child: ListTile(
                    title: Text(offer['product_name']),
                    subtitle: Text("Discount: \$${offer['discount_price']} (was \$${offer['original_price']})"),
                    trailing: Text("Valid until: ${offer['valid_until']}"),
                  ),
                );
              },
            ),
    );
  }
}
