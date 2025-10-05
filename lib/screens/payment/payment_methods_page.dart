import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/payment_service.dart';
import '../../themes/role_theme_manager.dart';
import 'add_payment_method_page.dart';
import 'payment_method_details_page.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  List<Map<String, dynamic>> paymentMethods = [];
  List<Map<String, dynamic>> userPaymentMethods = [];
  Map<String, dynamic>? defaultPaymentMethod;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      isLoading = true;
    });

    try {
      final results = await Future.wait([
        PaymentService.getPaymentMethods(),
        PaymentService.getUserPaymentMethods(),
        PaymentService.getDefaultPaymentMethod(),
      ]);

      setState(() {
        paymentMethods = results[0] as List<Map<String, dynamic>>;
        userPaymentMethods = results[1] as List<Map<String, dynamic>>;
        defaultPaymentMethod = results[2] as Map<String, dynamic>?;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading payment methods: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColors = context.roleColors;

    return Scaffold(
      backgroundColor: roleColors.background,
      appBar: AppBar(
        title: Text(
          'Payment Methods',
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
            icon: Icon(Icons.add, color: roleColors.primary),
            onPressed: () => _navigateToAddPaymentMethod(),
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingState(roleColors)
          : _buildContent(roleColors),
    );
  }

  Widget _buildLoadingState(RoleColorScheme roleColors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(roleColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading payment methods...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: roleColors.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(RoleColorScheme roleColors) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildDefaultPaymentMethod(roleColors),
              const SizedBox(height: 24),
              _buildAvailablePaymentMethods(roleColors),
              const SizedBox(height: 24),
              _buildUserPaymentMethods(roleColors),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultPaymentMethod(RoleColorScheme roleColors) {
    if (defaultPaymentMethod == null) {
      return _buildNoDefaultPaymentMethod(roleColors);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Default Payment Method',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: roleColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _buildPaymentMethodCard(defaultPaymentMethod!, roleColors, isDefault: true),
      ],
    );
  }

  Widget _buildNoDefaultPaymentMethod(RoleColorScheme roleColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: roleColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: roleColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.payment,
            size: 48,
            color: roleColors.primary.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'No Default Payment Method',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: roleColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a payment method to get started',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: roleColors.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddPaymentMethod(),
            icon: const Icon(Icons.add),
            label: const Text('Add Payment Method'),
            style: ElevatedButton.styleFrom(
              backgroundColor: roleColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailablePaymentMethods(RoleColorScheme roleColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Payment Methods',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: roleColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...paymentMethods.map((method) => _buildAvailablePaymentMethodCard(method, roleColors)),
      ],
    );
  }

  Widget _buildAvailablePaymentMethodCard(Map<String, dynamic> method, RoleColorScheme roleColors) {
    final isAdded = userPaymentMethods.any((userMethod) => userMethod['payment_method_id'] == method['id']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: roleColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdded ? Colors.green.withOpacity(0.3) : roleColors.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getPaymentMethodColor(method['type']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                PaymentService.getPaymentMethodIcon(method['type']),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method['name'],
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: roleColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  method['description'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: roleColors.onSurface.withOpacity(0.7),
                  ),
                ),
                if (method['processing_fee_percentage'] > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Fee: ${method['processing_fee_percentage']}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: roleColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isAdded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Added',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () => _navigateToAddPaymentMethod(method),
              child: Text(
                'Add',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: roleColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserPaymentMethods(RoleColorScheme roleColors) {
    if (userPaymentMethods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Payment Methods',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: roleColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...userPaymentMethods.map((method) => _buildUserPaymentMethodCard(method, roleColors)),
      ],
    );
  }

  Widget _buildUserPaymentMethodCard(Map<String, dynamic> method, RoleColorScheme roleColors) {
    final isDefault = method['is_default'] == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildPaymentMethodCard(method, roleColors, isDefault: isDefault),
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method, RoleColorScheme roleColors, {bool isDefault = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getPaymentMethodColor(method['type']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    PaymentService.getPaymentMethodIcon(method['type']),
                    style: const TextStyle(fontSize: 24),
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
                          method['name'],
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: roleColors.onSurface,
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Default',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: roleColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (method['card_last_four'] != null)
                      Text(
                        '**** **** **** ${method['card_last_four']}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: roleColors.onSurface.withOpacity(0.7),
                        ),
                      )
                    else if (method['bank_name'] != null)
                      Text(
                        method['bank_name'],
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: roleColors.onSurface.withOpacity(0.7),
                        ),
                      )
                    else
                      Text(
                        method['description'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: roleColors.onSurface.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handlePaymentMethodAction(value, method),
                itemBuilder: (context) => [
                  if (!isDefault)
                    const PopupMenuItem(
                      value: 'set_default',
                      child: Text('Set as Default'),
                    ),
                  const PopupMenuItem(
                    value: 'view_details',
                    child: Text('View Details'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
                child: Icon(
                  Icons.more_vert,
                  color: roleColors.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  void _handlePaymentMethodAction(String action, Map<String, dynamic> method) {
    switch (action) {
      case 'set_default':
        _setAsDefault(method);
        break;
      case 'view_details':
        _viewDetails(method);
        break;
      case 'delete':
        _deletePaymentMethod(method);
        break;
    }
  }

  Future<void> _setAsDefault(Map<String, dynamic> method) async {
    try {
      final success = await PaymentService.setDefaultPaymentMethod(method['payment_method_id']);
      if (success) {
        _loadPaymentMethods();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Default payment method updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating default payment method: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewDetails(Map<String, dynamic> method) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentMethodDetailsPage(paymentMethod: method),
      ),
    );
  }

  Future<void> _deletePaymentMethod(Map<String, dynamic> method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: Text('Are you sure you want to delete ${method['name']}?'),
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
        final success = await PaymentService.deletePaymentMethod(method['id']);
        if (success) {
          _loadPaymentMethods();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment method deleted'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
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

  void _navigateToAddPaymentMethod([Map<String, dynamic>? method]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPaymentMethodPage(selectedMethod: method),
      ),
    ).then((_) => _loadPaymentMethods());
  }
}
