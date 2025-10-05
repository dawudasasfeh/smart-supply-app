import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/delivery_api_service.dart';
import '../../themes/role_theme_manager.dart';
import '../../constants/app_dimensions.dart';
import '../../l10n/app_localizations.dart';
import '../Distributor/Notifications_Page.dart';

class DistributorDashboard extends StatefulWidget {
  const DistributorDashboard({super.key});

  @override
  State<DistributorDashboard> createState() => _DistributorDashboardState();
}

class _DistributorDashboardState extends State<DistributorDashboard> 
    with TickerProviderStateMixin {
  String? token;
  String userName = 'Distributor';
  bool isLoading = true;
  Map<String, dynamic> dashboardStats = {};
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDashboardData();
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
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }
  
  Future<void> _loadDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('token');
      userName = prefs.getString('username') ?? prefs.getString('name') ?? 'Distributor';
      
      if (token != null && token!.isNotEmpty) {
        final stats = await ApiService.getDistributorStats(token!);
        setState(() {
          dashboardStats = stats;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading dashboard data: $e');
      setState(() => isLoading = false);
    }
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = AppLocalizations.of(context);
    final distributorColors = DistributorColors(isDark: isDark);
    final bgColor = isDark ? Colors.black : Colors.white;
    
    if (isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: _buildLoadingScreen(isDark),
      );
    }
    
    return Scaffold(
      backgroundColor: bgColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isDark),
            SliverToBoxAdapter(
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroHeader(isDark),
                      const SizedBox(height: 16),
                      _buildKpiRow(isDark),
                      const SizedBox(height: 24),
                      _buildSmartAssignmentCard(isDark),
                      const SizedBox(height: 24),
                      _buildStatsGrid(isDark),
                      const SizedBox(height: 24),
                      _buildTodayHighlights(isDark),
                      const SizedBox(height: 24),
                      _buildQuickActionsGrid(isDark),
                      const SizedBox(height: 24),
                      _buildInventoryAlerts(isDark),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HERO HEADER
  Widget _buildHeroHeader(bool isDark) {
    final locale = AppLocalizations.of(context);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.local_shipping_rounded, size: 22, color: Color(0xFFFF9800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale?.isRTL == true ? 'مرحباً' : 'Good day',
                  style: GoogleFonts.inter(fontSize: 12, color: subtextColor),
                ),
                Text(
                  userName,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFFFF9800), size: 14),
                const SizedBox(width: 4),
                Text('Distributor', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFFF9800))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // KPI PILL ROW
  Widget _buildKpiRow(bool isDark) {
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final primary = const Color(0xFFFF9800);

    final kpis = [
      {'label': 'Orders', 'value': (dashboardStats['total_orders'] ?? 0).toString(), 'icon': Icons.receipt_long},
      {'label': 'Active', 'value': (dashboardStats['active_deliveries'] ?? 0).toString(), 'icon': Icons.local_shipping_outlined},
      {'label': 'Revenue', 'value': (dashboardStats['total_revenue'] ?? '\$0').toString(), 'icon': Icons.attach_money},
      {'label': 'On-time', 'value': (dashboardStats['on_time_delivery_rate'] ?? '0%').toString(), 'icon': Icons.check_circle_outline},
    ];

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kpis.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final k = kpis[index];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: primary.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(k['icon'] as IconData, size: 18, color: primary),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    k['value'] as String,
                    key: ValueKey(k['value'] as String),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  k['label'] as String,
                  style: GoogleFonts.inter(fontSize: 12, color: subtextColor),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildLoadingScreen(bool isDark) {
    final distributorColors = DistributorColors(isDark: isDark);
    
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: distributorColors.primary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(distributorColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Loading Dashboard...',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAppBar(bool isDark) {
    final locale = AppLocalizations.of(context);
    final distributorColors = DistributorColors(isDark: isDark);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final bgColor = isDark ? Colors.black : Colors.white;
    
    return SliverAppBar(
      expandedHeight: AppDimensions.appBarExpandedHeight,
      floating: false,
      pinned: true,
      backgroundColor: bgColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: bgColor,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [distributorColors.primary, distributorColors.primary.withValues(alpha: 0.8)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: distributorColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              locale?.translate('dashboard') ?? 'Dashboard',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              locale?.isRTL == true ? 'إدارة التوزيع' : 'Distribution Management',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: subtextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0A0A0A) : Colors.black,
                          borderRadius: BorderRadius.circular(10),
                          border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
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
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DistributorNotificationsPage(),
                              ),
                            );
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
                              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pushNamed(context, '/chatList', arguments: {'role': 'distributor'});
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
  
  Widget _buildWelcomeCard(bool isDark) {
    final locale = AppLocalizations.of(context);
    final distributorColors = DistributorColors(isDark: isDark);
    final cardColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale?.isRTL == true ? 'مرحباً بك،' : 'Welcome back,',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  locale?.isRTL == true 
                      ? 'إليك ملخص عملياتك اليوم'
                      : 'Here\'s your operations overview',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: subtextColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [distributorColors.primary, distributorColors.primary.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: distributorColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
  
  // TALABAT-STYLE SMART ASSIGNMENT
  Widget _buildSmartAssignmentCard(bool isDark) {
    final locale = AppLocalizations.of(context);
    final distributorColors = DistributorColors(isDark: isDark);
    final cardBg = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    final unassignedOrders = dashboardStats['pending_orders'] ?? 0;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Simple emoji icon
              Text(
                '✨',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale?.isRTL == true ? 'التعيين الذكي' : 'Smart Assignment',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      locale?.isRTL == true ? 'مدعوم بالذكاء الاصطناعي' : 'AI-Powered',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, '/deliveryManagement');
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  locale?.isRTL == true ? 'لوحة التحكم' : 'Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: distributorColors.primary,
                  ),
                ),
              ),
              if (unassignedOrders > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: distributorColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unassignedOrders',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: distributorColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            locale?.isRTL == true 
                ? 'تعيين تلقائي للطلبات بناءً على الموقع'
                : 'Auto-assign orders based on location',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _performSmartAssignment();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: distributorColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      locale?.isRTL == true ? 'تعيين الآن' : 'Assign Now',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _performSmartAssignment() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF0A0A0A) 
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Assigning orders...',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      // Perform smart assignment
      final result = await DeliveryApiService.performSmartAssignment();
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Show result
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final assignedCount = result['count'] ?? 0;
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Success!',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Text(
              '$assignedCount orders assigned successfully',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Refresh dashboard data
                  _loadDashboardData();
                },
                child: Text(
                  'OK',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: DistributorColors(isDark: isDark).primary,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assignment failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
  
  // TALABAT-STYLE STATS - Simple with Emojis
  Widget _buildStatsGrid(bool isDark) {
    // Hidden per user request; KPI pill row replaces this.
    return const SizedBox.shrink();
  }
  
  
  Widget _buildPerformanceOverview(bool isDark) {
    final locale = AppLocalizations.of(context);
    final distributorColors = DistributorColors(isDark: isDark);
    
    // Extract data from backend
    final revenue = dashboardStats['total_revenue'] ?? '\$0';
    final growth = dashboardStats['growth_percentage'] ?? '+0%';
    final deliveryRate = dashboardStats['on_time_delivery_rate'] ?? '0%';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            distributorColors.primary,
            distributorColors.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: distributorColors.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Emoji icon
          Text(
            '📊',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale?.isRTL == true ? 'الإيرادات' : 'Revenue',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  revenue.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              growth.toString(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '✓',
            style: GoogleFonts.inter(
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            deliveryRate.toString(),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  // TALABAT-STYLE TODAY'S HIGHLIGHTS
  Widget _buildTodayHighlights(bool isDark) {
    final locale = AppLocalizations.of(context);
    final cardBg = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    final newOrders = dashboardStats['new_orders_today'] ?? 0;
    final lowStockItems = dashboardStats['low_stock_items'] ?? 0;
    final avgDeliveryTime = dashboardStats['avg_delivery_time'] ?? '0h';
    
    final highlights = [
      {'emoji': '🛍️', 'value': newOrders.toString(), 'label': locale?.isRTL == true ? 'اليوم' : 'Today'},
      {'emoji': '⚠️', 'value': lowStockItems.toString(), 'label': locale?.isRTL == true ? 'مخزون' : 'Stock'},
      {'emoji': '⏱️', 'value': avgDeliveryTime.toString(), 'label': locale?.isRTL == true ? 'وقت' : 'Time'},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          locale?.isRTL == true ? 'أبرز أحداث اليوم' : 'Today\'s Highlights',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: highlights.map((highlight) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      highlight['emoji'] as String,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          highlight['value'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          highlight['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: subtextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  // TALABAT-STYLE QUICK ACTIONS - Small 3D Icons
  Widget _buildQuickActionsGrid(bool isDark) {
    final locale = AppLocalizations.of(context);
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    
    final actions = [
      {
        'title': locale?.isRTL == true ? 'المنتجات' : 'Products',
        'route': '/manageProducts',
        'emoji': '📦',
      },
      {
        'title': locale?.isRTL == true ? 'الطلبات' : 'Orders',
        'route': '/supplierOrders',
        'emoji': '🛒',
      },
      {
        'title': locale?.isRTL == true ? 'التوصيل' : 'Delivery',
        'route': '/deliveryManagement',
        'emoji': '🚚',
      },
      {
        'title': locale?.isRTL == true ? 'العروض' : 'Offers',
        'route': '/manageOffers',
        'emoji': '🎁',
      },
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          locale?.isRTL == true ? 'إجراءات سريعة' : 'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: actions.map((action) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, action['route'] as String);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        // Small rounded square with 3D icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: isDark 
                                ? const Color(0xFF1F1F1F)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              action['emoji'] as String,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          action['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildInventoryAlerts(bool isDark) {
    final locale = AppLocalizations.of(context);
    final distributorColors = DistributorColors(isDark: isDark);
    final cardColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: const Color(0xFF1F1F1F)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale?.isRTL == true ? 'حالة المخزون' : 'Inventory Status',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      locale?.isRTL == true ? 'تحديثات فورية' : 'Real-time updates',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/manageProducts');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: distributorColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      locale?.isRTL == true ? 'عرض الكل' : 'View All',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: distributorColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark 
                  ? const Color(0xFF1F1F1F).withValues(alpha: 0.3)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: const Color(0xFFF59E0B),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    locale?.isRTL == true 
                        ? 'لديك عناصر منخفضة المخزون تحتاج إلى إعادة تخزين'
                        : 'You have low stock items that need restocking',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
