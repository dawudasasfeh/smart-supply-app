import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../themes/role_theme_manager.dart';
import '../../constants/app_dimensions.dart';
import '../EditProfile_page.dart';
import '../../l10n/app_localizations.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  // Data
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  bool showFullToken = false;
  
  // Animation Controllers
  AnimationController? _fadeController;
  AnimationController? _slideController;
  AnimationController? _avatarController;
  
  // Animations
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  Animation<double>? _avatarAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadProfileData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _avatarController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController!, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic,
    ));
    
    _avatarAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _avatarController!, curve: Curves.easeInOut),
    );
    
    _fadeController?.forward();
    _slideController?.forward();
    _avatarController?.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _slideController?.dispose();
    _avatarController?.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // Load cached data first
      final cachedData = {
        'username': prefs.getString('username') ?? prefs.getString('name') ?? 'Supermarket User',
        'email': prefs.getString('email') ?? 'user@example.com',
        'role': prefs.getString('role') ?? 'supermarket',
        'token': token,
        'phone': '+201001234567',
        'address': 'Cairo, Egypt',
        'memberSince': '2024',
      };
      
      setState(() {
        profileData = cachedData;
        isLoading = false;
      });
      
      // Try to fetch fresh data from API
      if (token.isNotEmpty) {
        final userId = prefs.getInt('userId') ?? prefs.getInt('user_id') ?? 0;
        if (userId > 0) {
          // Try to get fresh profile data (if API method exists)
          // final freshData = await ApiService.getUserProfile(token, userId);
          // if (freshData != null && mounted) {
          //   setState(() {
          //     profileData = {...cachedData, ...freshData};
          //   });
          // }
        }
      }
    } catch (e) {
      print('❌ Error loading profile: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final supermarketColors = SupermarketColors(isDark: isDark);
    final locale = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      body: _fadeAnimation != null ? FadeTransition(
        opacity: _fadeAnimation!,
        child: _buildContent(context, isDark, supermarketColors, locale),
      ) : _buildContent(context, isDark, supermarketColors, locale),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, SupermarketColors colors, AppLocalizations? locale) {
    if (isLoading) {
      return _buildLoadingState(colors);
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(context, isDark, colors, locale),
        SliverToBoxAdapter(
          child: _slideAnimation != null ? SlideTransition(
            position: _slideAnimation!,
            child: _buildProfileContent(context, isDark, colors, locale),
          ) : _buildProfileContent(context, isDark, colors, locale),
        ),
      ],
    );
  }

  Widget _buildLoadingState(SupermarketColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Profile...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: colors.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark, SupermarketColors colors, AppLocalizations? locale) {
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // App Bar Row
                  Row(
                    children: [
                      // Profile Icon
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
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Title and Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              locale?.isRTL == true ? 'الملف الشخصي' : 'Profile',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              locale?.isRTL == true ? 'المعلومات الشخصية' : 'Personal Information',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: subtextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // Action Buttons
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
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            // Navigate to notifications
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
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
                            Icons.settings_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, '/settings');
                          },
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

  Widget _buildProfileAvatar(SupermarketColors colors) {
    final username = profileData?['username'] ?? 'User';
    final initials = username.split(' ').map((name) => name.isNotEmpty ? name[0] : '').take(2).join().toUpperCase();
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, bool isDark, SupermarketColors colors, AppLocalizations? locale) {
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return Padding(
      padding: EdgeInsets.all(AppDimensions.screenPadding),
      child: Column(
        children: [
          // Profile Avatar Section
          Center(
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      (profileData?['username'] ?? 'U').substring(0, 1).toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Edit Icon
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF000000) : Colors.white,
                        width: 3,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showProfileImageOptions(context, isDark, locale),
                        borderRadius: BorderRadius.circular(18),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            profileData?['username'] ?? 'User',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          // Email
          Text(
            profileData?['email'] ?? 'user@example.com',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 8),
          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              (profileData?['role'] ?? 'supermarket').toString().toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3B82F6),
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(height: AppDimensions.sectionSpacing),
          
          _buildProfileInfoCard(isDark, colors, locale),
          SizedBox(height: AppDimensions.sectionSpacing),
          _buildAccountDetailsCard(isDark, colors, locale),
          SizedBox(height: AppDimensions.sectionSpacing),
          _buildTokenCard(isDark, colors, locale),
          SizedBox(height: AppDimensions.sectionSpacing * 3),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard(bool isDark, SupermarketColors colors, AppLocalizations? locale) {
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final cardBg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    
    return Container(
      padding: EdgeInsets.all(AppDimensions.cardPadding + 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: colors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                locale?.isRTL == true ? 'معلومات شخصية' : 'Personal Information',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(locale?.isRTL == true ? 'الاسم' : 'Name', profileData?['username'] ?? 'N/A', Icons.badge_outlined, isDark),
          const SizedBox(height: 16),
          _buildInfoRow(locale?.isRTL == true ? 'البريد الإلكتروني' : 'Email', profileData?['email'] ?? 'N/A', Icons.email_outlined, isDark),
          const SizedBox(height: 16),
          _buildInfoRow(locale?.isRTL == true ? 'الدور' : 'Role', (profileData?['role'] ?? 'supermarket').toString().toUpperCase(), Icons.work_outline_rounded, isDark),
        ],
      ),
    );
  }

  Widget _buildAccountDetailsCard(bool isDark, SupermarketColors colors, AppLocalizations? locale) {
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final cardBg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.store_outlined,
                color: colors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                locale?.isRTL == true ? 'تفاصيل الحساب' : 'Account Details',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(locale?.isRTL == true ? 'رقم الهاتف' : 'Phone', profileData?['phone'] ?? '+201001234567', Icons.phone_outlined, isDark),
          const SizedBox(height: 16),
          _buildInfoRow(locale?.isRTL == true ? 'العنوان' : 'Address', profileData?['address'] ?? 'Cairo, Egypt', Icons.location_on_outlined, isDark),
          const SizedBox(height: 16),
          _buildInfoRow(locale?.isRTL == true ? 'عضو منذ' : 'Member Since', profileData?['memberSince'] ?? '2024', Icons.calendar_today_outlined, isDark),
        ],
      ),
    );
  }

  Widget _buildTokenCard(bool isDark, SupermarketColors colors, AppLocalizations? locale) {
    final token = profileData?['token'] ?? '';
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final cardBg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F1F) : colors.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: colors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                locale?.isRTL == true ? 'رمز الأمان' : 'Security Token',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        showFullToken 
                          ? token
                          : token.isNotEmpty 
                            ? '${token.substring(0, 20)}...'
                            : 'No token available',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          showFullToken = !showFullToken;
                        });
                        HapticFeedback.lightImpact();
                      },
                      icon: Icon(
                        showFullToken ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                      tooltip: showFullToken ? 'Hide Token' : 'Show Token',
                    ),
                  ],
                ),
                if (token.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: token));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Token copied to clipboard'),
                            backgroundColor: colors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Token'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDark) {
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF94A3B8);
    final iconBg = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF1F5F9);
    final iconColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: subtextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showProfileImageOptions(BuildContext context, bool isDark, AppLocalizations? locale) {
    HapticFeedback.lightImpact();
    
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final cardBg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              locale?.isRTL == true ? 'صورة الملف الشخصي' : 'Profile Picture',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),
            
            // View Photo Option
            _buildImageOption(
              context,
              icon: Icons.visibility_rounded,
              title: locale?.isRTL == true ? 'عرض الصورة' : 'View Photo',
              subtitle: locale?.isRTL == true ? 'اعرض صورة ملفك الشخصي' : 'View your profile picture',
              color: const Color(0xFF3B82F6),
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                _viewProfileImage(context, isDark);
              },
            ),
            
            const SizedBox(height: 12),
            
            // Take Photo Option
            _buildImageOption(
              context,
              icon: Icons.camera_alt_rounded,
              title: locale?.isRTL == true ? 'التقط صورة' : 'Take Photo',
              subtitle: locale?.isRTL == true ? 'التقط صورة جديدة' : 'Take a new picture',
              color: const Color(0xFF10B981),
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Upload Photo Option
            _buildImageOption(
              context,
              icon: Icons.photo_library_rounded,
              title: locale?.isRTL == true ? 'اختر من المعرض' : 'Choose from Gallery',
              subtitle: locale?.isRTL == true ? 'اختر صورة من المعرض' : 'Select from your gallery',
              color: const Color(0xFFF59E0B),
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                _uploadPhoto();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Text(
                  locale?.isRTL == true ? 'إلغاء' : 'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: subtextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewProfileImage(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    (profileData?['username'] ?? 'U').substring(0, 1).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                profileData?['username'] ?? 'User',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _takePhoto() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)?.isRTL == true
              ? 'فتح الكاميرا...'
              : 'Opening camera...',
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    // TODO: Implement camera functionality using image_picker package
    // final ImagePicker picker = ImagePicker();
    // final XFile? photo = await picker.pickImage(source: ImageSource.camera);
  }

  void _uploadPhoto() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)?.isRTL == true
              ? 'فتح المعرض...'
              : 'Opening gallery...',
        ),
        backgroundColor: const Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    // TODO: Implement gallery functionality using image_picker package
    // final ImagePicker picker = ImagePicker();
    // final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  }

  void _navigateToEditProfile() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfilePage(role: 'supermarket'),
      ),
    ).then((_) {
      // Refresh profile data when returning from edit
      _loadProfileData();
    });
  }
}
