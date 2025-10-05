import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DeliveryBottomNavigation extends StatelessWidget {
  final String currentRoute;
  final VoidCallback? onDashboardRefresh;

  const DeliveryBottomNavigation({
    super.key,
    required this.currentRoute,
    this.onDashboardRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBottomNavItem(
                context: context,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Dashboard',
                route: '/deliveryDashboard',
                isActive: currentRoute == '/deliveryDashboard' || currentRoute == '/',
              ),
              _buildBottomNavItem(
                context: context,
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment,
                label: 'Orders',
                route: '/assignedOrders',
                isActive: currentRoute == '/assignedOrders',
              ),
              _buildBottomNavItem(
                context: context,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                route: '/deliveryProfile',
                isActive: currentRoute == '/deliveryProfile',
              ),
              _buildBottomNavItem(
                context: context,
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                route: '/settings',
                isActive: currentRoute == '/settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => _handleNavigation(context, route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, String route) {
    // Don't navigate if already on the current route
    if (route == currentRoute) {
      // If on dashboard and tapped dashboard, refresh
      if (route == '/deliveryDashboard' && onDashboardRefresh != null) {
        onDashboardRefresh!();
      }
      return;
    }

    switch (route) {
      case '/deliveryDashboard':
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/deliveryDashboard',
          (route) => false,
        );
        break;
      case '/assignedOrders':
        Navigator.pushNamed(context, '/assignedOrders');
        break;
      case '/deliveryProfile':
        Navigator.pushNamed(context, '/deliveryProfile');
        break;
      case '/settings':
        Navigator.pushNamed(context, '/settings');
        break;
      default:
        Navigator.pushNamed(context, route);
    }
  }

  // Static method to get current route identifier from route name
  static String getCurrentRoute(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route?.settings.name != null) {
      return route!.settings.name!;
    }
    
    // Fallback: try to determine from widget type
    final widget = context.widget;
    if (widget.toString().contains('DeliveryDashboard')) {
      return '/deliveryDashboard';
    } else if (widget.toString().contains('AssignedOrders')) {
      return '/assignedOrders';
    } else if (widget.toString().contains('DeliveryProfile')) {
      return '/deliveryProfile';
    } else if (widget.toString().contains('Settings')) {
      return '/settings';
    }
    
    return '/deliveryDashboard'; // Default
  }
}
