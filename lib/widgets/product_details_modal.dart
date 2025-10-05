import 'package:flutter/material.dart';

class ProductDetailsModal extends StatelessWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic>? distributor;
  final dynamic offer;

  const ProductDetailsModal({
    Key? key,
    required this.product,
    required this.distributor,
    this.offer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // You can expand this with more product/distributor details as needed
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product['name'] ?? 'Unknown Product', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (distributor != null)
              Text(distributor!['name'] ?? 'Unknown Distributor', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            if (offer != null)
              Text('Offer: ${(offer['discount_price'] ?? 0).toString()}', style: const TextStyle(fontSize: 16, color: Colors.green)),
            // ...add more product/distributor/offer details as needed...
          ],
        ),
      ),
    );
  }
}
