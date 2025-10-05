import 'package:flutter/material.dart';

class RatingDetailsModal extends StatelessWidget {
  final double avgRating;
  final int reviewCount;
  final List<String> recentComments;

  const RatingDetailsModal({
    Key? key,
    required this.avgRating,
    required this.reviewCount,
    required this.recentComments,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Text(
                  avgRating > 0 ? avgRating.toStringAsFixed(1) : 'No rating',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                if (reviewCount > 0)
                  Text('($reviewCount reviews)', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            if (recentComments.isNotEmpty) ...[
              const Text('Recent Comments:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...recentComments.map((comment) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text('"$comment"', style: const TextStyle(fontStyle: FontStyle.italic)),
                  )),
            ],
            // ...add more rating details as needed...
          ],
        ),
      ),
    );
  }
}
