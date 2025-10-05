import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/payment_service.dart';
import '../../themes/role_theme_manager.dart';
import 'payment_failed_page.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final double totalAmount;
  final List<Map<String, dynamic>> items;

  const PaymentPage({
    super.key,
    required this.order,
    required this.totalAmount,
    required this.items,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  List<Map<String, dynamic>> paymentMethods = [];
  List<Map<String, dynamic>> userPaymentMethods = [];
  Map<String, dynamic>? selectedPaymentMethod;
  bool isLoading = true;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await PaymentService.getPaymentMethods();
      final userMethods = await PaymentService.getUserPaymentMethods();
      
      // If no payment methods in database, use fallback
      final effectiveMethods = methods.isEmpty ? _getFallbackPaymentMethods() : methods;
      
      setState(() {
        paymentMethods = effectiveMethods;
        userPaymentMethods = userMethods;
        isLoading = false;
      });
    } catch (e) {
      // Use fallback payment methods if API fails
      setState(() {
        paymentMethods = _getFallbackPaymentMethods();
        userPaymentMethods = [];
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using default payment methods'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFallbackPaymentMethods() {
    return [
      {
        'id': 1,
        'name': 'Cash on Delivery',
        'type': 'cod',
        'description': 'Pay with cash when you receive your order',
        'icon': 'money',
        'is_active': true,
        'processing_fee_percentage': 0.0,
      },
      {
        'id': 2,
        'name': 'Card Payment',
        'type': 'card',
        'description': 'Visa, Mastercard, Amex & other cards accepted',
        'icon': 'credit_card',
        'is_active': true,
        'processing_fee_percentage': 2.5,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final roleColors = context.roleColors;

    return Scaffold(
      backgroundColor: roleColors.background,
      appBar: AppBar(
        title: Text(
          'Payment',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: roleColors.onSurface,
          ),
        ),
        backgroundColor: roleColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: roleColors.onSurface),
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
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildOrderSummary(roleColors),
                    const SizedBox(height: 24),
                    _buildPaymentMethods(roleColors),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
        _buildPaymentButton(roleColors),
      ],
    );
  }

  Widget _buildOrderSummary(RoleColorScheme roleColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: roleColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: roleColors.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: roleColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Order Summary',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: roleColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: roleColors.onSurface,
                ),
              ),
              Text(
                PaymentService.formatCurrency(widget.totalAmount),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: roleColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods(RoleColorScheme roleColors) {
    final availableMethods = paymentMethods.where((method) {
      final minAmount = double.tryParse(method['min_amount']?.toString() ?? '0') ?? 0.0;
      final maxAmount = double.tryParse(method['max_amount']?.toString() ?? '999999') ?? 999999.0;
      return widget.totalAmount >= minAmount && widget.totalAmount <= maxAmount;
    }).toList();

    if (availableMethods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: roleColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: roleColors.outline.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.payment_outlined,
              color: roleColors.onSurface.withOpacity(0.5),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No payment methods available for this amount',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: roleColors.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Payment Method',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: roleColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ...availableMethods.map((method) => _buildPaymentMethodCard(method, roleColors)),
      ],
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method, RoleColorScheme roleColors) {
    final isSelected = selectedPaymentMethod?['id'] == method['id'];
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPaymentMethod = method;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? roleColors.primary.withOpacity(0.1) : roleColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? roleColors.primary : roleColors.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: roleColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getPaymentMethodIcon(method['name']),
                color: roleColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method['name'] ?? 'Unknown',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: roleColors.onSurface,
                    ),
                  ),
                  if (method['description'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      method['description'],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: roleColors.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: roleColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(String? methodName) {
    switch (methodName?.toLowerCase()) {
      case 'credit card':
        return Icons.credit_card;
      case 'debit card':
        return Icons.payment;
      case 'paypal':
        return Icons.account_balance_wallet;
      case 'bank transfer':
        return Icons.account_balance;
      case 'cash on delivery':
        return Icons.money;
      default:
        return Icons.payment;
    }
  }

  Widget _buildPaymentButton(RoleColorScheme roleColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: roleColors.surface,
        border: Border(
          top: BorderSide(
            color: roleColors.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (selectedPaymentMethod != null && !isProcessing)
                ? _processPayment
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: roleColors.primary,
              foregroundColor: roleColors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isProcessing
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(roleColors.onPrimary),
                    ),
                  )
                : Text(
                    selectedPaymentMethod == null
                        ? 'Select Payment Method'
                        : 'Pay ${PaymentService.formatCurrency(widget.totalAmount)}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (selectedPaymentMethod == null) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final orderIdRaw = widget.order['id'];
      int orderId;
      if (orderIdRaw is int) {
        orderId = orderIdRaw;
      } else if (orderIdRaw is double) {
        orderId = orderIdRaw.round();
      } else if (orderIdRaw is String) {
        orderId = int.tryParse(orderIdRaw) ?? 0;
      } else {
        orderId = 0;
      }
      
      final paymentMethodIdRaw = selectedPaymentMethod!['id'];
      int paymentMethodId;
      if (paymentMethodIdRaw is int) {
        paymentMethodId = paymentMethodIdRaw;
      } else if (paymentMethodIdRaw is double) {
        paymentMethodId = paymentMethodIdRaw.round();
      } else if (paymentMethodIdRaw is String) {
        paymentMethodId = int.tryParse(paymentMethodIdRaw) ?? 0;
      } else {
        paymentMethodId = 0;
      }
      
      if (orderId == 0) {
        throw Exception('Invalid order ID: $orderIdRaw');
      }
      if (paymentMethodId == 0) {
        throw Exception('Invalid payment method ID: $paymentMethodIdRaw');
      }
      
      final result = await PaymentService.processPayment(
        orderId: orderId,
        paymentMethodId: paymentMethodId,
        amount: widget.totalAmount,
      );

      if (result != null) {
        if (mounted) {
          setState(() {
            isProcessing = false;
          });
          // Return true to indicate successful payment
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Payment processing failed - no result returned');
      }
    } catch (e) {
      print('❌ Payment processing error: $e');
      
      setState(() {
        isProcessing = false;
      });
      
      if (mounted) {
        // Show error in a snackbar first
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        
        // Then navigate to failure page
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentFailedPage(
                order: widget.order,
                error: e.toString(),
              ),
            ),
          );
        }
      }
    }
  }
}
