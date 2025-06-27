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

    setState(() {
      offers = currentOffers;
      products = allProducts.where((p) {
        return selectedDistributorId == null ||
            p['distributor_id'] == selectedDistributorId;
      }).toList();
    });
  }

  void addToCart(Map<String, dynamic> product) {
    final matchedOffer = offers.firstWhere(
      (offer) => offer['product_id'] == product['id'],
      orElse: () => null,
    );

    final price = matchedOffer != null
        ? matchedOffer['discount_price']
        : product['price'];

    final cartItem = {
      'id': product['id'],
      'name': product['name'],
      'price': price,
      'quantity': 1,
      'distributor_id': product['distributor_id'],
    };

    CartManager().addItem(cartItem);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${product['name']} added to cart")),
    );
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
            onPressed: () => Navigator.pushNamed(context, '/cart'),
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
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(product['name'])),
                              if (offer != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
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
                            ],
                          ),
                          subtitle: offer != null
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
                          trailing: IconButton(
                            icon: const Icon(Icons.add_shopping_cart),
                            onPressed: () => addToCart(product),
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
