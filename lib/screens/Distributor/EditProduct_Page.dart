import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class EditProductPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController stockController;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.product['name']);
    priceController = TextEditingController(text: widget.product['price'].toString());
    stockController = TextEditingController(text: widget.product['stock'].toString());
  }

  Future<void> updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final success = await ApiService.updateProduct(
      token,
      widget.product['id'],
      {
        "name": nameController.text.trim(),
        "price": double.parse(priceController.text.trim()),
        "stock": int.parse(stockController.text.trim()),
      },
    );

    setState(() => isSubmitting = false);

    if (success && context.mounted) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update product")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Product"), backgroundColor: Colors.deepPurple),
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
                onPressed: isSubmitting ? null : updateProduct,
                icon: const Icon(Icons.save),
                label: const Text("Save Changes"),
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
