import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language_provider.dart';
import '../widgets/location_input_widget.dart';

class SignupPage extends StatefulWidget {
  final bool skipWelcome;
  
  const SignupPage({super.key, this.skipWelcome = false});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Profile controllers
  final _storeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _vehicleTypeController = TextEditingController();

  // Location data
  String? _selectedAddress;
  double? _selectedLatitude;
  double? _selectedLongitude;

  String _selectedRole = 'supermarket';
  int _currentStep = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    // Skip welcome screen if coming from login page
    if (widget.skipWelcome) {
      _currentStep = 1; // Start at Basic Info step
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(1);
        }
      });
    }
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _storeNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _fullNameController.dispose();
    _vehicleTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFFAFAFA);
    
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildWelcomeStep(),
                    _buildBasicInfoStep(),
                    _buildRoleSelectionStep(),
                    _buildProfileStep(),
                  ],
                ),
              ),
            ),
            
            // Floating Settings Buttons - Top Right
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  // Language Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Text(
                        AppLocalizations.of(context)?.isRTL == true ? 'EN' : 'ع',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      onPressed: () {
                        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
                        languageProvider.toggleLanguage();
                      },
                      tooltip: 'Switch Language',
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Dark Mode Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: () {
                        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                        themeProvider.toggleTheme();
                      },
                      tooltip: 'Toggle Dark Mode',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1F2937);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Creative Logo - Chain Links
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 15,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 15,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: Icon(
                          Icons.link,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text(
                locale?.translate('welcome_to_silsila') ?? 'Welcome to Silsila',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                locale?.translate('join_platform_description') ?? 'Join our supply chain management platform and streamline your business operations',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: subtextColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 56),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    locale?.translate('get_started') ?? 'Get Started',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text.rich(
                  TextSpan(
                    text: locale?.translate('already_have_account') ?? 'Already have an account? ',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: subtextColor,
                    ),
                    children: [
                      TextSpan(
                        text: locale?.signIn ?? 'Sign In',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    final locale = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(locale?.translate('basic_information') ?? 'Basic Information', locale?.translate('tell_us_about_yourself') ?? 'Tell us about yourself', 2, 4),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: locale?.translate('full_name') ?? 'Full Name',
                      hint: locale?.translate('your_full_name') ?? 'Your full name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return locale?.translate('full_name_required') ?? 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _emailController,
                      label: locale?.emailAddress ?? 'Email Address',
                      hint: 'your@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return locale?.pleaseEnterEmail ?? 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _passwordController,
                      label: locale?.password ?? 'Password',
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return locale?.pleaseEnterPassword ?? 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return locale?.translate('password_min_length') ?? 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: locale?.translate('confirm_password') ?? 'Confirm Password',
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return locale?.translate('please_confirm_password') ?? 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return locale?.translate('passwords_do_not_match') ?? 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelectionStep() {
    final locale = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(locale?.translate('choose_your_role') ?? 'Choose Your Role', locale?.translate('select_business_type') ?? 'Select your business type', 3, 4),
          const SizedBox(height: 32),
          Expanded(
            child: Column(
              children: [
                _buildRoleCard(
                  role: 'supermarket',
                  title: locale?.translate('supermarket') ?? 'Supermarket',
                  description: locale?.translate('supermarket_description') ?? 'Retail store looking for suppliers',
                  icon: Icons.store,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _buildRoleCard(
                  role: 'distributor',
                  title: locale?.translate('distributor') ?? 'Distributor',
                  description: locale?.translate('distributor_description') ?? 'Supplier providing products to retailers',
                  icon: Icons.local_shipping,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildRoleCard(
                  role: 'delivery',
                  title: locale?.translate('delivery_partner') ?? 'Delivery Partner',
                  description: locale?.translate('delivery_description') ?? 'Delivery service provider',
                  icon: Icons.delivery_dining,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    final locale = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(locale?.translate('profile_details') ?? 'Profile Details', locale?.translate('complete_your_profile') ?? 'Complete your profile', 4, 4),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _profileFormKey,
                child: _buildRoleSpecificFields(),
              ),
            ),
          ),
          _buildNavigationButtons(isLast: true),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String title, String subtitle, int current, int total) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1F2937);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_currentStep > 0)
              IconButton(
                onPressed: _previousStep,
                icon: Icon(Icons.arrow_back, color: textColor, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const Spacer(),
            Text(
              '$current of $total',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: subtextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: current / total,
            minHeight: 6,
            backgroundColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: subtextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1F2937);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
              letterSpacing: 0.1,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 15,
              color: subtextColor.withOpacity(0.5),
            ),
            prefixIcon: Icon(icon, size: 20, color: subtextColor),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1F2937);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF9FAFB);
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final isSelected = _selectedRole == role;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSpecificFields() {
    final locale = AppLocalizations.of(context);
    switch (_selectedRole) {
      case 'supermarket':
        return Column(
          children: [
            _buildTextField(
              controller: _storeNameController,
              label: locale?.translate('store_name') ?? 'Store Name',
              hint: locale?.translate('your_store_name') ?? 'Your store name',
              icon: Icons.store,
              validator: (value) => value?.isEmpty ?? true ? (locale?.translate('store_name_required') ?? 'Store name is required') : null,
            ),
            const SizedBox(height: 20),
            LocationInputWidget(
              label: locale?.translate('store_address') ?? 'Store Address',
              hint: locale?.translate('enter_store_address') ?? 'Enter your store address or select on map',
              initialAddress: _selectedAddress,
              initialPosition: _selectedLatitude != null && _selectedLongitude != null 
                  ? LatLng(_selectedLatitude!, _selectedLongitude!) 
                  : null,
              onLocationChanged: (address, position) {
                setState(() {
                  _selectedAddress = address;
                  _addressController.text = address;
                  if (position != null) {
                    _selectedLatitude = position.latitude;
                    _selectedLongitude = position.longitude;
                  }
                });
              },
              validator: (value) => value?.isEmpty ?? true ? (locale?.translate('address_required') ?? 'Address is required') : null,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _phoneController,
              label: locale?.translate('phone_number') ?? 'Phone Number',
              hint: locale?.translate('your_phone_number') ?? 'Your phone number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
          ],
        );
      case 'distributor':
        return Column(
          children: [
            _buildTextField(
              controller: _companyNameController,
              label: locale?.translate('company_name') ?? 'Company Name',
              hint: locale?.translate('your_company_name') ?? 'Your company name',
              icon: Icons.business,
              validator: (value) => value?.isEmpty ?? true ? (locale?.translate('company_name_required') ?? 'Company name is required') : null,
            ),
            const SizedBox(height: 20),
            LocationInputWidget(
              label: locale?.translate('business_address') ?? 'Business Address',
              hint: locale?.translate('enter_business_address') ?? 'Enter your business address or select on map',
              initialAddress: _selectedAddress,
              initialPosition: _selectedLatitude != null && _selectedLongitude != null 
                  ? LatLng(_selectedLatitude!, _selectedLongitude!) 
                  : null,
              onLocationChanged: (address, position) {
                setState(() {
                  _selectedAddress = address;
                  _addressController.text = address;
                  if (position != null) {
                    _selectedLatitude = position.latitude;
                    _selectedLongitude = position.longitude;
                  }
                });
              },
              validator: (value) => value?.isEmpty ?? true ? (locale?.translate('address_required') ?? 'Address is required') : null,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _phoneController,
              label: locale?.translate('business_phone') ?? 'Business Phone',
              hint: locale?.translate('your_business_phone') ?? 'Your business phone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
          ],
        );
      case 'delivery':
        return Column(
          children: [
            _buildTextField(
              controller: _fullNameController,
              label: locale?.translate('full_name') ?? 'Full Name',
              hint: locale?.translate('your_full_name') ?? 'Your full name',
              icon: Icons.person,
              validator: (value) => value?.isEmpty ?? true ? (locale?.translate('full_name_required') ?? 'Full name is required') : null,
            ),
            const SizedBox(height: 20),
            LocationInputWidget(
              label: locale?.translate('store_address') ?? 'Address',
              hint: locale?.translate('enter_address') ?? 'Enter your address or select on map',
              initialAddress: _selectedAddress,
              initialPosition: _selectedLatitude != null && _selectedLongitude != null 
                  ? LatLng(_selectedLatitude!, _selectedLongitude!) 
                  : null,
              onLocationChanged: (address, position) {
                setState(() {
                  _selectedAddress = address;
                  _addressController.text = address;
                  if (position != null) {
                    _selectedLatitude = position.latitude;
                    _selectedLongitude = position.longitude;
                  }
                });
              },
              validator: (value) => value?.isEmpty ?? true ? (locale?.translate('address_required') ?? 'Address is required') : null,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _phoneController,
              label: locale?.translate('phone_number') ?? 'Phone Number',
              hint: locale?.translate('your_phone_number') ?? 'Your phone number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _vehicleTypeController,
              label: locale?.translate('vehicle_type') ?? 'Vehicle Type',
              hint: locale?.translate('vehicle_type_hint') ?? 'e.g., Motorcycle, Car, Van',
              icon: Icons.directions_car,
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildNavigationButtons({bool isLast = false}) {
    final locale = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: AppColors.primary),
                ),
                child: Text(
                  locale?.translate('back') ?? 'Back',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () {
                print('🔘 Button tapped! isLast: $isLast, currentStep: $_currentStep');
                if (isLast) {
                  print('🔘 Create Account button tapped!');
                  _handleSignup();
                } else {
                  print('🔘 Continue button tapped!');
                  _nextStep();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isLast ? (locale?.translate('create_account') ?? 'Create Account') : (locale?.translate('continue_button') ?? 'Continue'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 1 && !_formKey.currentState!.validate()) {
      return;
    }
    
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleSignup() async {
    print('🚀 Signup button pressed!');
    
    // Check if we have basic info filled
    if (_nameController.text.trim().isEmpty || 
        _emailController.text.trim().isEmpty || 
        _passwordController.text.isEmpty) {
      print('❌ Basic info missing');
      _showErrorSnackBar('Please complete all previous steps first.');
      return;
    }
    
    // Validate profile form
    if (!_profileFormKey.currentState!.validate()) {
      print('❌ Profile form validation failed');
      _showErrorSnackBar('Please fill in all required fields correctly.');
      return;
    }

    print('✅ Form validation passed');
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final profileData = _buildProfileData();
      print('📋 Profile data: $profileData');
      
      print('📡 Calling API...');
      final result = await ApiService.signup({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'role': _selectedRole,
        'profile': profileData,
      });
      
      print('📥 API result: $result');
      final success = result != null;

      if (success) {
        print('🎉 Signup successful!');
        HapticFeedback.heavyImpact();
        _showSuccessDialog();
      } else {
        print('❌ Signup failed');
        // Check if it's a "user already exists" error
        if (result != null && result.toString().contains('User already exists')) {
          _showErrorSnackBar('An account with this email already exists. Please use a different email or sign in instead.');
        } else {
          _showErrorSnackBar('Signup failed. Please try again.');
        }
      }
    } catch (e) {
      print('💥 Error during signup: $e');
      // Check for specific error types
      if (e.toString().contains('User already exists')) {
        _showErrorSnackBar('An account with this email already exists. Please use a different email or sign in instead.');
      } else if (e.toString().contains('timeout') || e.toString().contains('Connection timeout')) {
        _showErrorSnackBar('Connection timeout. Please check if the backend server is running and try again.');
      } else if (e.toString().contains('Connection refused') || e.toString().contains('Network error')) {
        _showErrorSnackBar('Cannot connect to server. Please make sure the backend is running on localhost:5000.');
      } else {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _buildProfileData() {
    Map<String, dynamic> baseData = {
      'address': _addressController.text.trim(),
    };

    // Add location coordinates if available
    if (_selectedLatitude != null && _selectedLongitude != null) {
      baseData['latitude'] = _selectedLatitude;
      baseData['longitude'] = _selectedLongitude;
    }

    switch (_selectedRole) {
      case 'supermarket':
        return {
          ...baseData,
          'store_name': _storeNameController.text.trim(),
          'phone': _phoneController.text.trim(),
        };
      case 'distributor':
        return {
          ...baseData,
          'company_name': _companyNameController.text.trim(),
          'phone': _phoneController.text.trim(),
        };
      case 'delivery':
        return {
          ...baseData,
          'full_name': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'vehicle_type': _vehicleTypeController.text.trim().isEmpty 
              ? 'Motorcycle' 
              : _vehicleTypeController.text.trim(),
        };
      default:
        return baseData;
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Account Created!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your account has been created successfully. You can now sign in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue to Sign In'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    final isUserExistsError = message.contains('account with this email already exists');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
            if (isUserExistsError)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  Navigator.of(context).pop(); // Go back to login
                },
                child: const Text(
                  'Sign In',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}
