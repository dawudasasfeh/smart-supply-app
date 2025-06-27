import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class AddOfferPage extends StatefulWidget {
  final int productId;
  final String productName;

  const AddOfferPage({super.key, required this.productId, required this.productName});

  @override
  State<AddOfferPage> createState() => _AddOfferPageState();
}

class _AddOfferPageState extends State<AddOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _priceController = TextEditingController();
  DateTime? _selectedDate;
  bool isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final body = {
      "product_id": widget.productId,
      "product_name": widget.productName,
      "discount_price": double.tryParse(_priceController.text),
      "expiration_date": DateFormat('yyyy-MM-dd').format(_selectedDate!)
    };

    setState(() => isLoading = true);
    final success = await ApiService.addOffer(token, body);
    setState(() => isLoading = false);

    if (success) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Offer added")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to add offer")),
      );
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(today.year + 2),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Offer"), backgroundColor: Colors.deepPurple),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text("Product: ${widget.productName}", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Discount Price'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter discount price' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? "Select expiration date"
                          : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _submit,
                icon: const Icon(Icons.save),
                label: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Add Offer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
