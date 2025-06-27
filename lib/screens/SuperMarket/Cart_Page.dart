import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cartmanager_page.dart'; // ✅ assuming you already have this
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

    int? lastOrderId;
    String? lastDeliveryCode;

    for (var item in cart) {
      final res = await ApiService.placeOrderWithQR(
        token: token,
        productId: item['id'],
        distributorId: item['distributor_id'],
        quantity: item['quantity'],
      );
      if (res != null) {
        lastOrderId = res['order_id'];
        lastDeliveryCode = res['delivery_code'];
      }
    }

    CartManager().clearCart();
    setState(() => isLoading = false);

    if (!mounted || lastOrderId == null || lastDeliveryCode == null) return;

    Navigator.pushNamed(context, '/qrGenerate', arguments: {
      'orderId': lastOrderId,
      'deliveryCode': lastDeliveryCode,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartManager().cartItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Cart"),
        backgroundColor: Colors.deepPurple,
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
                      return Card(
                        margin: const EdgeInsets.all(10),
                        child: ListTile(
                          title: Text(item['name'] ?? item['product_name']),
                          subtitle: Text("Qty: ${item['quantity']}"),
                          trailing: Text("\$${item['price'] ?? item['discount_price']}"),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
