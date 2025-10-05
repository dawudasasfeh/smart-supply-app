import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_provider.dart';
import '../../themes/role_theme_manager.dart';
import '../../constants/app_dimensions.dart';
import '../../services/logout_helper.dart' as logout_helper;
import '../../widgets/change_password_dialog.dart';
import '../../widgets/language_selector.dart';
import '../../l10n/app_localizations.dart';

class ModernSettingsPage extends StatefulWidget {
  const ModernSettingsPage({Key? key}) : super(key: key);

  @override
  State<ModernSettingsPage> createState() => _ModernSettingsPageState();
}

class _ModernSettingsPageState extends State<ModernSettingsPage>
    with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Settings State
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _biometricEnabled = false;
  String _userRole = '';
  String _userName = '';
  String _userEmail = '';

  // UI State
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutExpo,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    // Staggered animation start
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userRole = prefs.getString('role') ?? '';
        _userName = prefs.getString('name') ?? 'User';
        _userEmail = prefs.getString('email') ?? '';
        _notificationsEnabled = prefs.getBool('notifications') ?? true;
        _soundEnabled = prefs.getBool('sound') ?? true;
        _vibrationEnabled = prefs.getBool('vibration') ?? true;
        _biometricEnabled = prefs.getBool('biometric') ?? false;
      });
      
      // Set role theme
      RoleThemeManager.setUserRole(_userRole);
    } catch (e) {
      _showErrorSnackBar('Failed to load settings');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
      
      HapticFeedback.lightImpact();
    } catch (e) {
      _showErrorSnackBar('Failed to save setting');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      body: _isLoading 
        ? _buildModernLoadingState(isDark, locale)
        : CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildModernAppBar(isDark, locale),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(AppDimensions.screenPadding, 0, AppDimensions.screenPadding, AppDimensions.screenPadding),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: AppDimensions.screenPadding),
                    _buildUserProfileSection(isDark, locale),
                    SizedBox(height: AppDimensions.sectionSpacing),
                    _buildSettingsGrid(isDark, locale),
                    SizedBox(height: AppDimensions.sectionSpacing),
                    _buildQuickActions(isDark, locale),
                    SizedBox(height: AppDimensions.screenPadding),
                  ]),
                ),
              ),
            ],
          ),
    );
  }

  // Modern Loading Animation with Pulsing Rings
  Widget _buildModernLoadingState(bool isDark, AppLocalizations? locale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 2000),
            builder: (context, value, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Transform.scale(
                    scale: 1.0 + (0.3 * value),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2 * (1 - value)),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  // Center icon
                  Transform.scale(
                    scale: 0.9 + (0.1 * value),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.9),
                            AppColors.primary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            locale?.isRTL == true ? 'جاري تحميل الإعدادات...' : 'Loading Settings...',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9CA3AF) : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Modern App Bar matching Dashboard Style
  Widget _buildModernAppBar(bool isDark, AppLocalizations? locale) {
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return SliverAppBar(
      expandedHeight: AppDimensions.appBarExpandedHeight,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF000000), const Color(0xFF000000)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppDimensions.screenPadding, AppDimensions.screenPadding, AppDimensions.screenPadding, AppDimensions.cardPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      // Settings Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.settings_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              locale?.isRTL == true ? '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a' : 'Settings',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            Text(
                              locale?.isRTL == true ? '\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u062a\u0637\u0628\u064a\u0642' : 'App Configuration',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Help Button
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0A0A0A) : Colors.black,
                          borderRadius: BorderRadius.circular(10),
                          border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.help_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () => _showHelpDialog(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfileSection(bool isDark, AppLocalizations? locale) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Animated Avatar
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.5 + (0.5 * value),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getRoleIcon(),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF9FAFB) : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userEmail,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getRoleDisplayName(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Edit Button
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.3 + (0.7 * value),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _navigateToProfile();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGrid(bool isDark, AppLocalizations? locale) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            locale?.isRTL == true ? 'التفضيلات' : 'Preferences',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF9FAFB) : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildToggleRow(
            locale?.isRTL == true ? 'الوضع الليلي' : 'Dark Mode',
            Icons.dark_mode_outlined,
            context.watch<ThemeProvider>().isDarkMode,
            (value) => _toggleDarkMode(),
            isDark,
          ),
          const SizedBox(height: 12),
          _buildLanguageSelector(),
          const SizedBox(height: 12),
          _buildToggleRow(
            locale?.isRTL == true ? 'الإشعارات' : 'Notifications',
            Icons.notifications_outlined,
            _notificationsEnabled,
            (value) {
              setState(() => _notificationsEnabled = value);
              _saveSetting('notifications', value);
            },
            isDark,
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            locale?.isRTL == true ? 'الصوت' : 'Sound',
            Icons.volume_up_outlined,
            _soundEnabled,
            (value) {
              setState(() => _soundEnabled = value);
              _saveSetting('sound', value);
            },
            isDark,
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            locale?.isRTL == true ? 'الاهتزاز' : 'Vibration',
            Icons.vibration,
            _vibrationEnabled,
            (value) {
              setState(() => _vibrationEnabled = value);
              _saveSetting('vibration', value);
            },
            isDark,
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            locale?.isRTL == true ? 'البصمة' : 'Biometric',
            Icons.fingerprint,
            _biometricEnabled,
            (value) {
              setState(() => _biometricEnabled = value);
              _saveSetting('biometric', value);
            },
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, animationValue, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: value 
                          ? AppColors.primary.withOpacity(0.1)
                          : (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: value 
                            ? AppColors.primary.withOpacity(0.2)
                            : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0)),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: value ? AppColors.primary : const Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.9,
                    child: Switch.adaptive(
                      value: value,
                      onChanged: (newValue) {
                        HapticFeedback.lightImpact();
                        onChanged(newValue);
                      },
                      activeColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withOpacity(0.3),
                      inactiveThumbColor: const Color(0xFF94A3B8),
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(bool isDark, AppLocalizations? locale) {
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            locale?.isRTL == true ? 'إجراءات سريعة' : 'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF9FAFB) : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            locale?.isRTL == true ? 'تغيير كلمة المرور' : 'Change Password',
            Icons.lock_outline,
            () => _showChangePasswordDialog(),
            AppColors.primary,
            isDark,
            index: 0,
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            locale?.isRTL == true ? 'المساعدة والدعم' : 'Help & Support',
            Icons.help_outline,
            () => _showHelpDialog(),
            AppColors.accent,
            isDark,
            index: 1,
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            locale?.isRTL == true ? 'تسجيل الخروج' : 'Logout',
            Icons.logout,
            () => _handleLogout(),
            Colors.red,
            isDark,
            index: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    VoidCallback onTap,
    Color color,
    bool isDark, {
    int index = 0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 100)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap();
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFF9FAFB) : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: isDark ? const Color(0xFF9CA3AF) : AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper Methods
  IconData _getRoleIcon() {
    switch (_userRole.toLowerCase()) {
      case 'supermarket':
        return Icons.store_rounded;
      case 'distributor':
        return Icons.local_shipping_rounded;
      case 'delivery':
        return Icons.delivery_dining_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _getRoleDisplayName() {
    switch (_userRole.toLowerCase()) {
      case 'supermarket':
        return 'Supermarket';
      case 'distributor':
        return 'Distributor';
      case 'delivery':
        return 'Delivery';
      default:
        return 'User';
    }
  }

  void _navigateToProfile() {
    // Navigate to profile page
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  void _toggleDarkMode() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setThemeMode(
      themeProvider.isDarkMode ? ThemeMode.light : ThemeMode.dark
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text('Contact support for assistance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.language,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Language',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          const LanguageSelector(showLabels: true),
        ],
      ),
    );
  }

  void _handleLogout() {
    logout_helper.logout(context);
  }
}
