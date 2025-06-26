import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class AddOfferPage extends StatefulWidget {
  final int productId;
  final String productName;

  const AddOfferPage({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<AddOfferPage> createState() => _AddOfferPageState();
}

class _AddOfferPageState extends State<AddOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController priceController = TextEditingController();
  bool isSubmitting = false;

  Future<void> submitOffer() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final double? discount = double.tryParse(priceController.text.trim());

    if (discount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid discount price")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    print('🔍 Submitting offer: productId=${widget.productId}, name=${widget.productName}, price=$discount');

    final success = await ApiService.addOffer(token, {
      "product_id": widget.productId,
      "product_name": widget.productName,
      "discount_price": discount,
    });

    setState(() => isSubmitting = false);

    if (success && context.mounted) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add offer")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Offer"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text("Product: ${widget.productName}", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Discount Price",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? "Enter discount price" : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: isSubmitting ? null : submitOffer,
                icon: const Icon(Icons.check),
                label: const Text("Add Offer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
