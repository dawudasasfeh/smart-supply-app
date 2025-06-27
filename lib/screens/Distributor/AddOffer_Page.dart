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
  final TextEditingController _discountPriceController = TextEditingController();
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) return;

    setState(() => _isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final success = await ApiService.addOffer(token, {
      'product_id': widget.productId,
      'product_name': widget.productName,
      'discount_price': double.parse(_discountPriceController.text),
      'expiration_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
    });

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer added successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add offer')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Offer'), backgroundColor: Colors.deepPurple),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text("Product: ${widget.productName}", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _discountPriceController,
                decoration: const InputDecoration(labelText: 'Discount Price'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter discount price' : null,
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(_selectedDate == null
                    ? 'Pick Expiration Date'
                    : 'Expires on: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}'),
                trailing: const Icon(Icons.calendar_month),
                onTap: _pickDate,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitOffer,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Add Offer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
