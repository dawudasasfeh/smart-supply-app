import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/payment_service.dart';
import '../../themes/role_theme_manager.dart';

class AddPaymentMethodPage extends StatefulWidget {
  final Map<String, dynamic>? selectedMethod;

  const AddPaymentMethodPage({
    super.key,
    this.selectedMethod,
  });

  @override
  State<AddPaymentMethodPage> createState() => _AddPaymentMethodPageState();
}

class _AddPaymentMethodPageState extends State<AddPaymentMethodPage> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cvvController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  
  Map<String, dynamic>? selectedPaymentMethod;
  bool isLoading = false;
  bool isDefault = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedMethod != null) {
      selectedPaymentMethod = widget.selectedMethod;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColors = context.roleColors;

    return Scaffold(
      backgroundColor: roleColors.background,
      appBar: AppBar(
        title: Text(
          'Add Payment Method',
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
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPaymentMethodSelection(roleColors),
                    const SizedBox(height: 24),
                    if (selectedPaymentMethod != null) ...[
                      _buildPaymentMethodForm(roleColors),
                      const SizedBox(height: 24),
                      _buildDefaultToggle(roleColors),
                    ],
                  ],
                ),
              ),
            ),
            _buildSaveButton(roleColors),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelection(RoleColorScheme roleColors) {
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
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: PaymentService.getPaymentMethods(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            
            final methods = snapshot.data ?? [];
            return Column(
              children: methods.map((method) => _buildPaymentMethodOption(method, roleColors)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption(Map<String, dynamic> method, RoleColorScheme roleColors) {
    final isSelected = selectedPaymentMethod?['id'] == method['id'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => selectedPaymentMethod = method),
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getPaymentMethodColor(method['type']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    PaymentService.getPaymentMethodIcon(method['type']),
                    style: const TextStyle(fontSize: 20),
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
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: roleColors.primary,
                  size: 24,
                )
              else
                Icon(
                  Icons.radio_button_unchecked,
                  color: roleColors.onSurface.withOpacity(0.3),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodForm(RoleColorScheme roleColors) {
    if (selectedPaymentMethod == null) return const SizedBox.shrink();
    
    switch (selectedPaymentMethod!['type']) {
      case 'card':
        return _buildCardForm(roleColors);
      case 'bank_transfer':
        return _buildBankTransferForm(roleColors);
      case 'digital_wallet':
        return _buildDigitalWalletForm(roleColors);
      default:
        return _buildGenericForm(roleColors);
    }
  }

  Widget _buildCardForm(RoleColorScheme roleColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: roleColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cardNumberController,
          decoration: InputDecoration(
            labelText: 'Card Number',
            hintText: '1234 5678 9012 3456',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Card number is required';
            }
            if (value.replaceAll(' ', '').length < 16) {
              return 'Please enter a valid card number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _expiryMonthController,
                decoration: InputDecoration(
                  labelText: 'Month',
                  hintText: 'MM',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Month is required';
                  }
                  final month = int.tryParse(value);
                  if (month == null || month < 1 || month > 12) {
                    return 'Invalid month';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _expiryYearController,
                decoration: InputDecoration(
                  labelText: 'Year',
                  hintText: 'YYYY',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Year is required';
                  }
                  final year = int.tryParse(value);
                  if (year == null || year < DateTime.now().year) {
                    return 'Invalid year';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _cvvController,
                decoration: InputDecoration(
                  labelText: 'CVV',
                  hintText: '123',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'CVV is required';
                  }
                  if (value.length < 3) {
                    return 'Invalid CVV';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBankTransferForm(RoleColorScheme roleColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bank Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: roleColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bankNameController,
          decoration: InputDecoration(
            labelText: 'Bank Name',
            hintText: 'National Bank of Egypt',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Bank name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _accountNumberController,
          decoration: InputDecoration(
            labelText: 'Account Number',
            hintText: '12345678901234567890',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Account number is required';
            }
            if (value.length < 10) {
              return 'Please enter a valid account number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDigitalWalletForm(RoleColorScheme roleColors) {
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
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: roleColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Digital Wallet Setup',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: roleColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Digital wallet payments are processed through our secure payment partners. No additional setup required.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: roleColors.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGenericForm(RoleColorScheme roleColors) {
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
        children: [
          Icon(
            Icons.payment,
            size: 48,
            color: roleColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Payment Method Added',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: roleColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This payment method will be available for your future orders.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: roleColors.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultToggle(RoleColorScheme roleColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: roleColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: roleColors.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.star,
            color: roleColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set as Default',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: roleColors.onSurface,
                  ),
                ),
                Text(
                  'Use this payment method by default for future orders',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: roleColors.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isDefault,
            onChanged: (value) => setState(() => isDefault = value),
            activeColor: roleColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(RoleColorScheme roleColors) {
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
          child: ElevatedButton(
            onPressed: selectedPaymentMethod != null && !isLoading ? _savePaymentMethod : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: roleColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Adding...',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Add Payment Method',
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

  Future<void> _savePaymentMethod() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final result = await PaymentService.addPaymentMethod(
        paymentMethodId: selectedPaymentMethod!['id'],
        isDefault: isDefault,
        cardLastFour: _cardNumberController.text.isNotEmpty 
            ? _cardNumberController.text.substring(_cardNumberController.text.length - 4)
            : null,
        cardBrand: _getCardBrand(_cardNumberController.text),
        bankName: _bankNameController.text.isNotEmpty ? _bankNameController.text : null,
        accountNumberMasked: _accountNumberController.text.isNotEmpty 
            ? '****${_accountNumberController.text.substring(_accountNumberController.text.length - 4)}'
            : null,
        expiryMonth: _expiryMonthController.text.isNotEmpty 
            ? int.tryParse(_expiryMonthController.text) 
            : null,
        expiryYear: _expiryYearController.text.isNotEmpty 
            ? int.tryParse(_expiryYearController.text) 
            : null,
      );

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment method added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Failed to add payment method');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding payment method: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _getCardBrand(String cardNumber) {
    if (cardNumber.startsWith('4')) return 'Visa';
    if (cardNumber.startsWith('5')) return 'MasterCard';
    if (cardNumber.startsWith('3')) return 'American Express';
    return null;
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
