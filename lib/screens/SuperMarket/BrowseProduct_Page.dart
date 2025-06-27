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
  List<dynamic> offers = [];
  List<Map<String, dynamic>> distributors = [];
  int? selectedDistributorId;

  @override
  void initState() {
    super.initState();
    fetchDistributors();
    fetchData();
  }

  Future<void> fetchDistributors() async {
    final result = await ApiService.getAllDistributors();
    setState(() => distributors = result);
  }

  Future<void> fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final allProducts = await ApiService.getProducts(token);
    final currentOffers = await ApiService.getOffers();

    List<dynamic> filtered = allProducts.where((p) {
      return selectedDistributorId == null || p['distributor_id'] == selectedDistributorId;
    }).toList();

    // Sort so zero-stock products go at the bottom, others alphabetically by name
    filtered.sort((a, b) {
      int stockA = a['stock'] ?? 0;
      int stockB = b['stock'] ?? 0;

      int zeroSortA = stockA == 0 ? 1 : 0;
      int zeroSortB = stockB == 0 ? 1 : 0;

      if (zeroSortA != zeroSortB) {
        return zeroSortA.compareTo(zeroSortB);
      }

      return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
    });

    setState(() {
      offers = currentOffers;
      products = filtered;
    });
  }

  Future<void> refreshProducts() async {
    await fetchData();
  }

  void addToCart(Map<String, dynamic> product) {
    final matchedOffer = offers.firstWhere(
      (offer) => offer['product_id'] == product['id'],
      orElse: () => null,
    );

    final price = matchedOffer != null ? matchedOffer['discount_price'] : product['price'];

    final cartItem = {
      'id': product['id'],
      'name': product['name'],
      'price': price,
      'quantity': 1,
      'distributor_id': product['distributor_id'],
      'stock': product['stock'] ?? 1,
    };

    CartManager().addItem(cartItem);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${product['name']} added to cart")),
    );
  }

  String formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Browse Products"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/cart');
              if (result == 'order_placed') {
                await refreshProducts();
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButton<int?>(
              hint: const Text("Filter by Supplier"),
              isExpanded: true,
              value: selectedDistributorId,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text("All Distributors"),
                ),
                ...distributors.map((d) {
                  return DropdownMenuItem<int?>(
                    value: d['id'],
                    child: Text(d['name']),
                  );
                }).toList(),
              ],
              onChanged: (val) {
                setState(() => selectedDistributorId = val);
                fetchData();
              },
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text("No products found"))
                : ListView.builder(
                    itemCount: products.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final offer = offers.firstWhere(
                        (o) => o['product_id'] == product['id'],
                        orElse: () => null,
                      );

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            height: 80,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      offer != null
                                          ? Row(
                                              children: [
                                                Text(
                                                  "\$${product['price']}",
                                                  style: const TextStyle(
                                                    decoration: TextDecoration.lineThrough,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "\$${offer['discount_price']}",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text("Price: \$${product['price']}"),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Stock: ${product['stock'] ?? 'N/A'}",
                                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                                if (offer != null)
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'On Sale',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "Expires: ${formatDate(offer['expiration_date'])}",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.add_shopping_cart),
                                  color: (product['stock'] ?? 0) > 0 ? Colors.deepPurple : Colors.grey,
                                  onPressed: (product['stock'] ?? 0) > 0 ? () => addToCart(product) : null,
                                  tooltip: (product['stock'] ?? 0) > 0 ? 'Add to cart' : 'Out of stock',
                                ),
                              ],
                            ),
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
