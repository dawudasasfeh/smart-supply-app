import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  bool isProcessing = false;
  String message = '';

  Future<void> handleScan(String code) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);

    await SharedPreferences.getInstance();
    // Assuming user_id saved at login (not used here directly but can be used if needed)
    // final userId = prefs.getInt('user_id');

    try {
      final parts = code.split(':');
      final orderId = int.tryParse(parts[0]);
      final deliveryCode = parts.length > 1 ? parts[1] : '';

      if (orderId == null || deliveryCode.isEmpty) {
        throw Exception("Invalid QR code format");
      }

      final success = await ApiService.verifyDelivery(orderId, deliveryCode);
      setState(() {
        message = success ? "✅ Delivery Verified!" : "❌ Invalid delivery code";
      });
    } catch (e) {
      setState(() => message = "❌ Error: ${e.toString()}");
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          isProcessing = false;
          message = '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                final barcode = capture.barcodes.first;
                final code = barcode.rawValue;
                if (code != null) {
                  handleScan(code);
                }
              },
            ),
          ),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  color: message.startsWith("✅") ? Colors.green : Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
