import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../themes/role_theme_manager.dart';

class PaymentSuccessPage extends StatelessWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> transaction;

  const PaymentSuccessPage({
    super.key,
    required this.order,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final roleColors = context.roleColors;

    return Scaffold(
      backgroundColor: roleColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Success Animation
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 80,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Success Message
                    Text(
                      'Payment Successful!',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: roleColors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      'Your payment has been processed successfully. You will receive a confirmation email shortly.',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: roleColors.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Transaction Details
                    _buildTransactionDetails(roleColors),
                  ],
                ),
              ),
              
              // Action Buttons
              _buildActionButtons(context, roleColors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionDetails(RoleColorScheme roleColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: roleColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: roleColors.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Details',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: roleColors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildDetailRow(
            'Transaction ID',
            transaction['transaction_id'] ?? 'N/A',
            roleColors,
          ),
          const SizedBox(height: 8),
          
          _buildDetailRow(
            'Order ID',
            '#${order['id']}',
            roleColors,
          ),
          const SizedBox(height: 8),
          
          _buildDetailRow(
            'Amount',
            '${transaction['amount']?.toStringAsFixed(2) ?? '0.00'} ${transaction['currency'] ?? 'EGP'}',
            roleColors,
          ),
          const SizedBox(height: 8),
          
          _buildDetailRow(
            'Payment Method',
            transaction['payment_method_name'] ?? 'N/A',
            roleColors,
          ),
          const SizedBox(height: 8),
          
          _buildDetailRow(
            'Status',
            'Completed',
            roleColors,
            valueColor: Colors.green,
          ),
          const SizedBox(height: 8),
          
          _buildDetailRow(
            'Date',
            _formatDate(transaction['created_at']),
            roleColors,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    RoleColorScheme roleColors, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: roleColors.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? roleColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, RoleColorScheme roleColors) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _navigateToOrders(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: roleColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'View Orders',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _navigateToHome(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: roleColors.primary,
              side: BorderSide(color: roleColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Continue Shopping',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToOrders(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/supermarket',
      (route) => false,
      arguments: {'initialIndex': 2}, // Orders tab
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/supermarket',
      (route) => false,
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}
