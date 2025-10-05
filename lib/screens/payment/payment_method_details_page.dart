import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/payment_service.dart';
import '../../themes/role_theme_manager.dart';

class PaymentMethodDetailsPage extends StatelessWidget {
  final Map<String, dynamic> paymentMethod;

  const PaymentMethodDetailsPage({
    super.key,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final roleColors = context.roleColors;

    return Scaffold(
      backgroundColor: roleColors.background,
      appBar: AppBar(
        title: Text(
          'Payment Method Details',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: roleColors.onSurface,
          ),
        ),
        backgroundColor: roleColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: roleColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: roleColors.primary),
            onPressed: () => _editPaymentMethod(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPaymentMethodCard(roleColors),
            const SizedBox(height: 24),
            _buildPaymentMethodInfo(roleColors),
            const SizedBox(height: 24),
            _buildUsageStats(roleColors),
            const SizedBox(height: 24),
            _buildActionButtons(context, roleColors),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(RoleColorScheme roleColors) {
    final isDefault = paymentMethod['is_default'] == true;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: roleColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? roleColors.primary.withOpacity(0.3) : roleColors.outline.withOpacity(0.2),
          width: isDefault ? 2 : 1,
        ),
        boxShadow: isDefault ? [
          BoxShadow(
            color: roleColors.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getPaymentMethodColor(paymentMethod['type']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    PaymentService.getPaymentMethodIcon(paymentMethod['type']),
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          paymentMethod['name'],
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: roleColors.onSurface,
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Default',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: roleColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      paymentMethod['description'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: roleColors.onSurface.withOpacity(0.7),
                      ),
                    ),
                    if (paymentMethod['card_last_four'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '**** **** **** ${paymentMethod['card_last_four']}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: roleColors.onSurface,
                        ),
                      ),
                    ],
                    if (paymentMethod['bank_name'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        paymentMethod['bank_name'],
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: roleColors.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodInfo(RoleColorScheme roleColors) {
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
            'Payment Method Information',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: roleColors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Type', paymentMethod['type']?.toString().toUpperCase() ?? 'N/A', roleColors),
          _buildInfoRow('Status', paymentMethod['is_verified'] == true ? 'Verified' : 'Unverified', roleColors),
          if (paymentMethod['card_brand'] != null)
            _buildInfoRow('Card Brand', paymentMethod['card_brand'], roleColors),
          if (paymentMethod['expiry_month'] != null && paymentMethod['expiry_year'] != null)
            _buildInfoRow('Expires', '${paymentMethod['expiry_month']}/${paymentMethod['expiry_year']}', roleColors),
          if (paymentMethod['processing_fee_percentage'] != null)
            _buildInfoRow('Processing Fee', '${paymentMethod['processing_fee_percentage']}%', roleColors),
          _buildInfoRow('Added', _formatDate(paymentMethod['created_at']), roleColors),
        ],
      ),
    );
  }

  Widget _buildUsageStats(RoleColorScheme roleColors) {
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
            'Usage Statistics',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: roleColors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total Transactions', '12', roleColors),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Total Amount', 'EGP 2,450', roleColors),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Success Rate', '95%', roleColors),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Last Used', '2 days ago', roleColors),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, RoleColorScheme roleColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: roleColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: roleColors.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: roleColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: roleColors.onSurface.withOpacity(0.7),
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
          child: ElevatedButton.icon(
            onPressed: () => _setAsDefault(context),
            icon: const Icon(Icons.star),
            label: const Text('Set as Default'),
            style: ElevatedButton.styleFrom(
              backgroundColor: roleColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _editPaymentMethod(context),
            icon: const Icon(Icons.edit),
            label: const Text('Edit Details'),
            style: OutlinedButton.styleFrom(
              foregroundColor: roleColors.primary,
              side: BorderSide(color: roleColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _deletePaymentMethod(context),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, RoleColorScheme roleColors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
              color: roleColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setAsDefault(BuildContext context) async {
    try {
      final success = await PaymentService.setDefaultPaymentMethod(paymentMethod['payment_method_id']);
      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Default payment method updated'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating default payment method: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editPaymentMethod(BuildContext context) {
    // Navigate to edit payment method page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit functionality coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _deletePaymentMethod(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: Text('Are you sure you want to delete ${paymentMethod['name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await PaymentService.deletePaymentMethod(paymentMethod['id']);
        if (success) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment method deleted'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting payment method: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getPaymentMethodColor(String type) {
    switch (type.toLowerCase()) {
      case 'card':
        return Colors.blue;
      case 'bank_transfer':
        return Colors.green;
      case 'cash':
        return Colors.orange;
      case 'digital_wallet':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
