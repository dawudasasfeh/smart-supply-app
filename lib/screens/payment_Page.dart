import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentSettingsPage extends StatefulWidget {
  const PaymentSettingsPage({super.key});

  @override
  State<PaymentSettingsPage> createState() => _PaymentSettingsPageState();
}

class _PaymentSettingsPageState extends State<PaymentSettingsPage> {
  final List<String> methods = ['Visa', 'MasterCard', 'PayPal', 'Cash on Delivery'];
  String selectedMethod = 'Cash on Delivery';

  @override
  void initState() {
    super.initState();
    loadMethod();
  }

  Future<void> loadMethod() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedMethod = prefs.getString('paymentMethod') ?? 'Cash on Delivery';
    });
  }

  Future<void> saveMethod(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('paymentMethod', value);
    setState(() => selectedMethod = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Settings"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.credit_card, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 20),
            const Text("Select your preferred payment method:"),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedMethod,
              items: methods
                  .map((method) =>
                      DropdownMenuItem(value: method, child: Text(method)))
                  .toList(),
              onChanged: (value) => saveMethod(value!),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.payment),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
