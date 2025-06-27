import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String selectedRole = 'Supermarket';

  final Map<String, TextEditingController> profileControllers = {
    'store_name': TextEditingController(),
    'address': TextEditingController(),
    'phone': TextEditingController(),
    'license_number': TextEditingController(),
    'tax_id': TextEditingController(),
    'opening_hours': TextEditingController(),
    'contact_person': TextEditingController(),
    'contact_phone': TextEditingController(),
    'website': TextEditingController(),
    'description': TextEditingController(),
    'company_name': TextEditingController(),
    'full_name': TextEditingController(),
    'vehicle_type': TextEditingController(),
    'license_plate': TextEditingController(),
  };

  bool isLoading = false;

  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _animController,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    profileControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  Widget _buildInputField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text, bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: (val) => (val == null || val.isEmpty) ? 'Please enter $label' : null,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  List<Widget> _buildProfileFields() {
    switch (selectedRole.toLowerCase()) {
      case 'supermarket':
        return [
          _buildInputField('Store Name', profileControllers['store_name']!),
          _buildInputField('Address', profileControllers['address']!),
          _buildInputField('Phone', profileControllers['phone']!, keyboardType: TextInputType.phone),
          _buildInputField('License Number', profileControllers['license_number']!),
          _buildInputField('Tax ID', profileControllers['tax_id']!),
          _buildInputField('Opening Hours', profileControllers['opening_hours']!),
          _buildInputField('Contact Person', profileControllers['contact_person']!),
          _buildInputField('Contact Phone', profileControllers['contact_phone']!, keyboardType: TextInputType.phone),
          _buildInputField('Website', profileControllers['website']!),
          _buildInputField('Description', profileControllers['description']!),
        ];
      case 'distributor':
        return [
          _buildInputField('Company Name', profileControllers['company_name']!),
          _buildInputField('Address', profileControllers['address']!),
          _buildInputField('Phone', profileControllers['phone']!, keyboardType: TextInputType.phone),
          _buildInputField('Email', emailController, keyboardType: TextInputType.emailAddress),
          _buildInputField('Tax ID', profileControllers['tax_id']!),
          _buildInputField('License Number', profileControllers['license_number']!),
          _buildInputField('Description', profileControllers['description']!),
        ];
      case 'delivery':
        return [
          _buildInputField('Full Name', profileControllers['full_name']!),
          _buildInputField('Phone', profileControllers['phone']!, keyboardType: TextInputType.phone),
          _buildInputField('Vehicle Type', profileControllers['vehicle_type']!),
          _buildInputField('License Plate', profileControllers['license_plate']!),
          _buildInputField('Address', profileControllers['address']!),
        ];
      default:
        return [];
    }
  }

  void _onRoleChanged(String? val) {
    if (val == null) return;
    setState(() {
      selectedRole = val;
      _animController.forward(from: 0);
    });
  }

  Future<void> handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    Map<String, dynamic> profileData = {};
    switch (selectedRole.toLowerCase()) {
      case 'supermarket':
        profileData = {
          'store_name': profileControllers['store_name']!.text.trim(),
          'address': profileControllers['address']!.text.trim(),
          'phone': profileControllers['phone']!.text.trim(),
          'license_number': profileControllers['license_number']!.text.trim(),
          'tax_id': profileControllers['tax_id']!.text.trim(),
          'opening_hours': profileControllers['opening_hours']!.text.trim(),
          'contact_person': profileControllers['contact_person']!.text.trim(),
          'contact_phone': profileControllers['contact_phone']!.text.trim(),
          'website': profileControllers['website']!.text.trim(),
          'description': profileControllers['description']!.text.trim(),
        };
        break;
      case 'distributor':
        profileData = {
          'company_name': profileControllers['company_name']!.text.trim(),
          'address': profileControllers['address']!.text.trim(),
          'phone': profileControllers['phone']!.text.trim(),
          'email': emailController.text.trim(),
          'tax_id': profileControllers['tax_id']!.text.trim(),
          'license_number': profileControllers['license_number']!.text.trim(),
          'description': profileControllers['description']!.text.trim(),
        };
        break;
      case 'delivery':
        profileData = {
          'full_name': profileControllers['full_name']!.text.trim(),
          'phone': profileControllers['phone']!.text.trim(),
          'vehicle_type': profileControllers['vehicle_type']!.text.trim(),
          'license_plate': profileControllers['license_plate']!.text.trim(),
          'address': profileControllers['address']!.text.trim(),
        };
        break;
    }

    final signupData = {
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'password': passwordController.text.trim(),
      'role': selectedRole,  // Keep first letter capitalized
      'profile': profileData, // Nested profile object
    };

    final result = await ApiService.signup(signupData);

    setState(() => isLoading = false);

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', result['token'] ?? '');
      await prefs.setString('role', result['user']['role'] ?? '');

      switch (selectedRole.toLowerCase()) {
        case 'supermarket':
          Navigator.pushReplacementNamed(context, '/supermarketDashboard');
          break;
        case 'distributor':
          Navigator.pushReplacementNamed(context, '/distributorDashboard');
          break;
        case 'delivery':
          Navigator.pushReplacementNamed(context, '/deliveryDashboard');
          break;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signup failed. Please check your details and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.person_add_alt_1, size: 44, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Create an Account',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildInputField('Full Name', nameController),
                  const SizedBox(height: 16),
                  _buildInputField('Email', emailController, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildInputField('Password', passwordController, obscureText: true),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'Supermarket', child: Text('Supermarket')),
                      DropdownMenuItem(value: 'Distributor', child: Text('Distributor')),
                      DropdownMenuItem(value: 'Delivery', child: Text('Delivery')),
                    ],
                    onChanged: _onRoleChanged,
                    decoration: InputDecoration(
                      labelText: 'Select Role',
                      filled: true,
                      fillColor: Colors.white,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildProfileFields()
                          .map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : handleSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 5,
                        shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Sign Up',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                    child: Text(
                      'Already have an account? Log in',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
