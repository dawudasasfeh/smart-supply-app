import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRGeneratorPage extends StatelessWidget {
  final int orderId;
  final String deliveryCode;

  const QRGeneratorPage({
    super.key,
    required this.orderId,
    required this.deliveryCode,
  });

  @override
  Widget build(BuildContext context) {
    final fullCode = "$orderId:$deliveryCode";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Delivery QR"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: fullCode,
              size: 240,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              "Show this QR code to the delivery person.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
