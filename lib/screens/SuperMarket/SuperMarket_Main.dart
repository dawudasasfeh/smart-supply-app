import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../themes/role_theme_manager.dart';
import '../../l10n/app_localizations.dart';
import 'Dashboard_Page.dart';
import 'BrowseProduct_Page.dart';
import 'Orders_Page.dart';
import 'profile_page_final.dart';
import '../common/settings_page.dart';

class SuperMarketMain extends StatefulWidget {
  final int? initialIndex;
  
  const SuperMarketMain({Key? key, this.initialIndex}) : super(key: key);

  @override
  State<SuperMarketMain> createState() => _SuperMarketMainState();
}

class _SuperMarketMainState extends State<SuperMarketMain> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
  }

  final List<Widget> _pages = [
    const SupermarketDashboard(),
    const BrowseProductsPage(),
    const OrdersPage(),
    const ProfilePage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final roleColors = context.roleColors;
    final locale = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final navItems = [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.shopping_bag_outlined),
        activeIcon: const Icon(Icons.shopping_bag),
        label: 'Products',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.shopping_cart_outlined),
        activeIcon: const Icon(Icons.shopping_cart),
        label: 'Orders',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outlined),
        activeIcon: const Icon(Icons.person),
        label: 'Profile',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.settings_outlined),
        activeIcon: const Icon(Icons.settings),
        label: 'Settings',
      ),
    ];
    
    final navBgColor = isDark ? const Color(0xFF000000) : roleColors.surface;
    final unselectedColor = isDark ? const Color(0xFF9CA3AF) : roleColors.onSurface.withOpacity(0.6);
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBgColor,
          boxShadow: [
            BoxShadow(
              color: roleColors.primary.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: navBgColor,
            selectedItemColor: roleColors.primary,
            unselectedItemColor: unselectedColor,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
              letterSpacing: 0.1,
            ),
            selectedFontSize: 12,
            unselectedFontSize: 11,
            iconSize: 24,
            elevation: 0,
            items: navItems,
          ),
        ),
      ),
    );
  }
}
