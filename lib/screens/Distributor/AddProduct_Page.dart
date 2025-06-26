import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  bool isSubmitting = false;

  Future<void> addProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final success = await ApiService.addProduct(token, {
      "name": nameController.text.trim(),
      "price": double.parse(priceController.text.trim()),
      "stock": int.parse(stockController.text.trim()),
    });

    setState(() => isSubmitting = false);

    if (success && context.mounted) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add product")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Product"), backgroundColor: Colors.deepPurple),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (val) => val == null || val.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
                validator: (val) => val == null || val.isEmpty ? 'Enter price' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock Quantity'),
                validator: (val) => val == null || val.isEmpty ? 'Enter stock' : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: isSubmitting ? null : addProduct,
                icon: const Icon(Icons.add),
                label: const Text("Add Product"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
