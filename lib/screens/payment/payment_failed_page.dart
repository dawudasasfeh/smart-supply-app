import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../themes/role_theme_manager.dart';
import 'payment_page.dart';

class PaymentFailedPage extends StatelessWidget {
  final Map<String, dynamic> order;
  final String error;

  const PaymentFailedPage({
    super.key,
    required this.order,
    required this.error,
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
                    // Error Animation
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Error Message
                    Text(
                      'Payment Failed',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: roleColors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      'We encountered an issue processing your payment. Please try again or contact support if the problem persists.',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: roleColors.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Error Details
                    _buildErrorDetails(roleColors),
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

  Widget _buildErrorDetails(RoleColorScheme roleColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Error Details',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            error,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: roleColors.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, RoleColorScheme roleColors) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _retryPayment(context),
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
              'Try Again',
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
              'Back to Home',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _contactSupport(context),
          child: Text(
            'Contact Support',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: roleColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _retryPayment(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          order: order,
          totalAmount: order['total_amount']?.toDouble() ?? 0.0,
          items: order['items'] ?? [],
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/supermarket',
      (route) => false,
    );
  }

  void _contactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Contact Support',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'If you continue to experience issues, please contact our support team:',
              style: GoogleFonts.inter(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            _buildContactInfo('Phone', '+20 123 456 7890'),
            const SizedBox(height: 8),
            _buildContactInfo('Email', 'support@smartsupply.com'),
            const SizedBox(height: 8),
            _buildContactInfo('WhatsApp', '+20 123 456 7890'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
