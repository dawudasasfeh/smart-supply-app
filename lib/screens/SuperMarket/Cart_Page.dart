import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cartmanager_page.dart';
import '../../services/api_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  String paymentMethod = 'Cash on Delivery';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadPaymentMethod();
  }

  Future<void> loadPaymentMethod() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      paymentMethod = prefs.getString('paymentMethod') ?? 'Cash on Delivery';
    });
  }

Future<void> placeOrders() async {
  setState(() => isLoading = true);
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token') ?? '';
  final cart = CartManager().cartItems;

  // Group by distributor_id
  final Map<int, List<Map<String, dynamic>>> groupedByDistributor = {};

  for (var item in cart) {
    final distributorId = item['distributor_id'];
    if (distributorId != null) {
      groupedByDistributor.putIfAbsent(distributorId, () => []).add(item);
    }
  }

  int? lastOrderId;
  String? lastDeliveryCode;

  for (var entry in groupedByDistributor.entries) {
    final distributorId = entry.key;
    final items = entry.value;

    final orderPayload = {
      'distributor_id': distributorId,
      'items': items
          .map((item) => {
                'product_id': item['id'],
                'quantity': item['quantity'],
                'price': (item['price'] is String)
                    ? double.tryParse(item['price']) ?? 0.0
                    : item['price'] ?? 0.0,
              })
          .toList(),
    };

    final response = await ApiService.placeMultiOrderWithQR(token, orderPayload);
    if (response != null) {
      lastOrderId = response['order_id'];
      lastDeliveryCode = response['delivery_code'];
    }
  }

  CartManager().clearCart();
  setState(() => isLoading = false);

  if (!mounted || lastOrderId == null || lastDeliveryCode == null) return;

  await Navigator.pushNamed(context, '/qrGenerate', arguments: {
    'orderId': lastOrderId,
    'deliveryCode': lastDeliveryCode,
  });

  Navigator.pop(context, 'order_placed');
}

  
  
  void incrementQuantity(int index) {
    final cart = CartManager().cartItems;
    final item = cart[index];
    final stock = item['stock'] ?? 1;
    final currentQty = item['quantity'] ?? 1;

    if (currentQty < stock) {
      CartManager().updateQuantity(item['id'], currentQty + 1);
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add more than available stock')),
      );
    }
  }

  void decrementQuantity(int index) {
    final cart = CartManager().cartItems;
    final item = cart[index];
    final currentQty = item['quantity'] ?? 1;

    if (currentQty > 1) {
      CartManager().updateQuantity(item['id'], currentQty - 1);
      setState(() {});
    }
  }

  void clearCart() {
    CartManager().clearCart();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartManager().cartItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Cart"),
        backgroundColor: Colors.deepPurple,
        actions: [
          if (cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Clear Cart',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear Cart'),
                    content: const Text('Are you sure you want to clear the cart?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          clearCart();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            )
        ],
      ),
      body: cart.isEmpty
          ? const Center(child: Text("Your cart is empty."))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      final stock = item['stock'] ?? 1;
                      final quantity = item['quantity'] ?? 1;

                      return Card(
                        margin: const EdgeInsets.all(10),
                        child: ListTile(
                          title: Text(item['name'] ?? item['product_name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Stock Available: $stock"),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text("Quantity: "),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: quantity > 1 ? () => decrementQuantity(index) : null,
                                  ),
                                  Text('$quantity'),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: quantity < stock ? () => incrementQuantity(index) : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Text(
                            "\$${item['price'] ?? item['discount_price']}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payment, color: Colors.deepPurple),
                          const SizedBox(width: 10),
                          Text("Payment: $paymentMethod"),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : placeOrders,
                          icon: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: const Text("Place Order"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
