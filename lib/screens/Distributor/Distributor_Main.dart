import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../themes/role_theme_manager.dart';
import 'DashBoard_Page.dart';
import 'ManageProducts_Page.dart';
import 'IncomingOrders_Page.dart';
import 'Profile_Page.dart';
import '../common/settings_page.dart';

class DistributorMain extends StatefulWidget {
  final int? initialIndex;
  
  const DistributorMain({Key? key, this.initialIndex}) : super(key: key);

  @override
  State<DistributorMain> createState() => _DistributorMainState();
}

class _DistributorMainState extends State<DistributorMain> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
  }

  final List<Widget> _pages = [
    const DistributorDashboard(),
    const ManageProductsPage(),
    const IncomingOrdersPage(),
    const DistributorProfilePage(),
    const SettingsPage(),
  ];

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.inventory_2_outlined),
      activeIcon: Icon(Icons.inventory_2),
      label: 'Inventory',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.shopping_cart_outlined),
      activeIcon: Icon(Icons.shopping_cart),
      label: 'Orders',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outlined),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final roleColors = context.roleColors;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: roleColors.surface,
          boxShadow: [
            BoxShadow(
              color: roleColors.primary.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, -3),
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
            backgroundColor: roleColors.surface,
            selectedItemColor: roleColors.primary,
            unselectedItemColor: roleColors.onSurface.withOpacity(0.6),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            elevation: 0,
            items: _navItems,
          ),
        ),
      ),
    );
  }
}
