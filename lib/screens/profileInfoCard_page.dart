import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isCopyable;

  const ProfileInfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isCopyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 28),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (isCopyable)
              Tooltip(
                message: "Copy $label",
                waitDuration: const Duration(milliseconds: 600),
                child: IconButton(
                  icon: Icon(Icons.copy, color: theme.colorScheme.primary),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("$label copied to clipboard")),
                    );
                  },
                ),
              )
          ],
        ),
      ),
    );
  }
}
