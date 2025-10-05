import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EnhancedDashboardBase extends StatelessWidget {
  final String userRole;
  final String userName;
  final List<Widget> children;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;

  const EnhancedDashboardBase({
    super.key,
    required this.userRole,
    required this.userName,
    required this.children,
    this.onNotificationTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(children),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(context),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getRoleDisplayName(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onNotificationTap,
                        icon: Stack(
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    '3',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
      actions: [
        IconButton(
          onPressed: onProfileTap,
          icon: const Icon(Icons.person_outline, color: Colors.white),
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    IconData icon;
    String tooltip;
    VoidCallback? onPressed;

    switch (userRole) {
      case 'supermarket':
        icon = Icons.add_shopping_cart;
        tooltip = 'New Order';
        onPressed = () => Navigator.pushNamed(context, '/browseProducts');
        break;
      case 'distributor':
        icon = Icons.add_box;
        tooltip = 'Add Product';
        onPressed = () => Navigator.pushNamed(context, '/addProduct');
        break;
      case 'delivery':
        icon = Icons.qr_code_scanner;
        tooltip = 'Scan QR';
        onPressed = () => Navigator.pushNamed(context, '/qrScan');
        break;
      default:
        return null;
    }

    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      child: Icon(icon),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    List<BottomNavigationBarItem> items;
    
    switch (userRole) {
      case 'supermarket':
        items = [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_outlined),
            activeIcon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Orders',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            activeIcon: Icon(Icons.star),
            label: 'Ratings',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
        ];
        break;
      case 'distributor':
        items = [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Orders',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            activeIcon: Icon(Icons.star),
            label: 'Ratings',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ];
        break;
      case 'delivery':
        items = [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Orders',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            activeIcon: Icon(Icons.star),
            label: 'Ratings',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ];
        break;
      default:
        items = [];
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
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
          type: BottomNavigationBarType.fixed,
          currentIndex: 0,
          onTap: (index) => _handleBottomNavTap(context, index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 10,
          ),
          elevation: 0,
          items: items,
        ),
      ),
    );
  }

  void _handleBottomNavTap(BuildContext context, int index) {
    switch (userRole) {
      case 'supermarket':
        switch (index) {
          case 0:
            Navigator.pushNamedAndRemoveUntil(context, '/supermarketDashboard', (route) => false);
            break;
          case 1:
            Navigator.pushNamed(context, '/inventory');
            break;
          case 2:
            Navigator.pushNamed(context, '/orderHistory');
            break;
          case 3:
            Navigator.pushNamed(context, '/rating', arguments: {'userRole': 'supermarket'});
            break;
          case 4:
            Navigator.pushNamed(context, '/chatList', arguments: {'role': 'supermarket'});
            break;
        }
        break;
      case 'distributor':
        switch (index) {
          case 0:
            Navigator.pushNamedAndRemoveUntil(context, '/distributorDashboard', (route) => false);
            break;
          case 1:
            Navigator.pushNamed(context, '/manageProducts');
            break;
          case 2:
            Navigator.pushNamed(context, '/supplierOrders');
            break;
          case 3:
            Navigator.pushNamed(context, '/rating', arguments: {'userRole': 'distributor'});
            break;
          case 4:
            Navigator.pushNamed(context, '/analytics');
            break;
        }
        break;
      case 'delivery':
        switch (index) {
          case 0:
            Navigator.pushNamedAndRemoveUntil(context, '/deliveryDashboard', (route) => false);
            break;
          case 1:
            Navigator.pushNamed(context, '/assignedOrders');
            break;
          case 2:
            Navigator.pushNamed(context, '/deliveredOrders');
            break;
          case 3:
            Navigator.pushNamed(context, '/rating', arguments: {'userRole': 'delivery'});
            break;
          case 4:
            Navigator.pushNamed(context, '/deliveryProfile');
            break;
        }
        break;
    }
  }

  String _getRoleDisplayName() {
    switch (userRole) {
      case 'supermarket':
        return 'Supermarket Manager';
      case 'distributor':
        return 'Distributor';
      case 'delivery':
        return 'Delivery Partner';
      default:
        return 'User';
    }
  }
}

class DashboardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback? onSeeAll;

  const DashboardSection({
    super.key,
    required this.title,
    required this.children,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                child: const Text('See All'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}
