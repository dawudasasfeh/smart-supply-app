import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../themes/role_theme_manager.dart';

class DashboardThemeShowcase extends StatefulWidget {
  const DashboardThemeShowcase({super.key});

  @override
  State<DashboardThemeShowcase> createState() => _DashboardThemeShowcaseState();
}

class _DashboardThemeShowcaseState extends State<DashboardThemeShowcase>
    with TickerProviderStateMixin {
  late TabController _tabController;
  UserRole selectedRole = UserRole.supermarket;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          selectedRole = UserRole.values[_tabController.index];
          RoleThemeManager.setUserRole(_getRoleString(selectedRole));
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleColors = RoleThemeManager.getCurrentColors();
    
    return Scaffold(
      backgroundColor: roleColors.background,
      appBar: AppBar(
        title: Text(
          'Dashboard Themes Showcase',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: roleColors.primary,
        foregroundColor: roleColors.onPrimary,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: roleColors.onPrimary,
          labelColor: roleColors.onPrimary,
          unselectedLabelColor: roleColors.onPrimary.withOpacity(0.7),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(
              icon: Icon(Icons.store),
              text: 'Supermarket',
            ),
            Tab(
              icon: Icon(Icons.local_shipping),
              text: 'Distributor',
            ),
            Tab(
              icon: Icon(Icons.delivery_dining),
              text: 'Delivery',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardPreview(UserRole.supermarket),
          _buildDashboardPreview(UserRole.distributor),
          _buildDashboardPreview(UserRole.delivery),
        ],
      ),
    );
  }

  Widget _buildDashboardPreview(UserRole role) {
    // Temporarily set the role for preview
    RoleThemeManager.setUserRole(_getRoleString(role));
    final roleColors = RoleThemeManager.getCurrentColors();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Theme Info Card
          _buildThemeInfoCard(role, roleColors),
          const SizedBox(height: 20),
          
          // Mock Dashboard Preview
          _buildMockDashboard(role, roleColors),
          const SizedBox(height: 20),
          
          // Navigation Preview
          _buildNavigationPreview(role, roleColors),
          const SizedBox(height: 20),
          
          // Color Palette
          _buildColorPalette(roleColors),
        ],
      ),
    );
  }

  Widget _buildThemeInfoCard(UserRole role, RoleColorScheme roleColors) {
    return Card(
      color: roleColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: roleColors.primaryGradient,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getRoleIcon(role),
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getRoleString(role)} Dashboard',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _getThemeDescription(role),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.palette, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Primary: ${_getColorName(role)} • Theme: ${_getThemeName(role)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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

  Widget _buildMockDashboard(UserRole role, RoleColorScheme roleColors) {
    return Card(
      color: roleColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Preview',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: roleColors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            
            // Mock Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: roleColors.primaryGradient,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _getRoleIcon(role),
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back!',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _getRoleWelcomeMessage(role),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Mock Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: _getMockStats(role, roleColors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationPreview(UserRole role, RoleColorScheme roleColors) {
    return Card(
      color: roleColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Navigation Preview',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: roleColors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: roleColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: roleColors.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: roleColors.surface,
                  selectedItemColor: roleColors.primary,
                  unselectedItemColor: roleColors.onSurface.withOpacity(0.6),
                  currentIndex: 0,
                  items: _getNavigationItems(role),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette(RoleColorScheme roleColors) {
    return Card(
      color: roleColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Color Palette',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: roleColors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildColorSwatch('Primary', roleColors.primary),
                _buildColorSwatch('Secondary', roleColors.secondary),
                _buildColorSwatch('Accent', roleColors.accent),
                _buildColorSwatch('Success', roleColors.success),
                _buildColorSwatch('Warning', roleColors.warning),
                _buildColorSwatch('Error', roleColors.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSwatch(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: RoleThemeManager.getCurrentColors().onSurface,
          ),
        ),
      ],
    );
  }

  List<Widget> _getMockStats(UserRole role, RoleColorScheme roleColors) {
    switch (role) {
      case UserRole.supermarket:
        return [
          _buildStatCard('Orders', '142', Icons.shopping_cart, roleColors),
          _buildStatCard('Revenue', '\$12.4K', Icons.attach_money, roleColors),
          _buildStatCard('Products', '1,234', Icons.inventory, roleColors),
          _buildStatCard('Rating', '4.8', Icons.star, roleColors),
        ];
      case UserRole.distributor:
        return [
          _buildStatCard('Deliveries', '89', Icons.local_shipping, roleColors),
          _buildStatCard('Revenue', '\$8.7K', Icons.trending_up, roleColors),
          _buildStatCard('Inventory', '567', Icons.warehouse, roleColors),
          _buildStatCard('Efficiency', '94%', Icons.speed, roleColors),
        ];
      case UserRole.delivery:
        return [
          _buildStatCard('Deliveries', '45', Icons.delivery_dining, roleColors),
          _buildStatCard('Distance', '234 km', Icons.route, roleColors),
          _buildStatCard('Rating', '4.9', Icons.star, roleColors),
          _buildStatCard('On Time', '96%', Icons.schedule, roleColors),
        ];
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, RoleColorScheme roleColors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: roleColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: roleColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: roleColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: roleColors.primary,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: roleColors.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  List<BottomNavigationBarItem> _getNavigationItems(UserRole role) {
    switch (role) {
      case UserRole.supermarket:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ];
      case UserRole.distributor:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ];
      case UserRole.delivery:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ];
    }
  }

  String _getRoleString(UserRole role) {
    switch (role) {
      case UserRole.supermarket:
        return 'supermarket';
      case UserRole.distributor:
        return 'distributor';
      case UserRole.delivery:
        return 'delivery';
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.supermarket:
        return Icons.store;
      case UserRole.distributor:
        return Icons.local_shipping;
      case UserRole.delivery:
        return Icons.delivery_dining;
    }
  }

  String _getThemeDescription(UserRole role) {
    switch (role) {
      case UserRole.supermarket:
        return 'Professional retail interface';
      case UserRole.distributor:
        return 'Logistics & supply chain focused';
      case UserRole.delivery:
        return 'Mobile & route optimized';
    }
  }

  String _getColorName(UserRole role) {
    switch (role) {
      case UserRole.supermarket:
        return 'Blue & Teal';
      case UserRole.distributor:
        return 'Orange & Deep Orange';
      case UserRole.delivery:
        return 'Green & Teal';
    }
  }

  String _getThemeName(UserRole role) {
    switch (role) {
      case UserRole.supermarket:
        return 'Trust & Reliability';
      case UserRole.distributor:
        return 'Energy & Efficiency';
      case UserRole.delivery:
        return 'Movement & Growth';
    }
  }

  String _getRoleWelcomeMessage(UserRole role) {
    switch (role) {
      case UserRole.supermarket:
        return 'Manage your store operations';
      case UserRole.distributor:
        return 'Optimize your supply chain';
      case UserRole.delivery:
        return 'Complete your deliveries';
    }
  }
}
