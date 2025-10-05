import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../themes/role_theme_manager.dart';

class RoleThemeDemo extends StatefulWidget {
  const RoleThemeDemo({super.key});

  @override
  State<RoleThemeDemo> createState() => _RoleThemeDemoState();
}

class _RoleThemeDemoState extends State<RoleThemeDemo> {
  UserRole selectedRole = UserRole.supermarket;

  @override
  Widget build(BuildContext context) {
    final roleColors = RoleThemeManager.getCurrentColors();
    
    return Scaffold(
      backgroundColor: roleColors.background,
      appBar: AppBar(
        title: Text(
          'Role-Based Themes Demo',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: roleColors.primary,
        foregroundColor: roleColors.onPrimary,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role Selector
            _buildRoleSelector(),
            const SizedBox(height: 24),
            
            // Current Theme Info
            _buildCurrentThemeInfo(),
            const SizedBox(height: 24),
            
            // Color Palette Demo
            _buildColorPalette(),
            const SizedBox(height: 24),
            
            // UI Components Demo
            _buildUIComponentsDemo(),
            const SizedBox(height: 24),
            
            // Cards Demo
            _buildCardsDemo(),
            const SizedBox(height: 24),
            
            // Buttons Demo
            _buildButtonsDemo(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    final roleColors = RoleThemeManager.getCurrentColors();
    
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
              'Select User Role',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: roleColors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: UserRole.values.map((role) {
                final isSelected = selectedRole == role;
                final roleColor = _getRoleColor(role);
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedRole = role;
                          RoleThemeManager.setUserRole(_getRoleString(role));
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? roleColor : roleColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: roleColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _getRoleIcon(role),
                              color: isSelected ? Colors.white : roleColor,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getRoleString(role),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : roleColor,
                              ),
                              textAlign: TextAlign.center,
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
        ),
      ),
    );
  }

  Widget _buildCurrentThemeInfo() {
    final roleColors = RoleThemeManager.getCurrentColors();
    
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
                  _getRoleIcon(selectedRole),
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getRoleString(selectedRole)} Theme',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Active role-based theme configuration',
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
              child: Text(
                _getThemeDescription(selectedRole),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    final roleColors = RoleThemeManager.getCurrentColors();
    
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
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: RoleThemeManager.getCurrentColors().onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildUIComponentsDemo() {
    final roleColors = RoleThemeManager.getCurrentColors();
    
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
              'UI Components',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: roleColors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            
            // Progress Indicators
            Text(
              'Progress Indicators',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: roleColors.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: 0.7,
              backgroundColor: roleColors.onSurface.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(roleColors.primary),
            ),
            const SizedBox(height: 16),
            
            // Switches
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Theme Switch',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: roleColors.onSurface,
                  ),
                ),
                Switch(
                  value: true,
                  onChanged: (value) {},
                  activeColor: roleColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsDemo() {
    final roleColors = RoleThemeManager.getCurrentColors();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Variations',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: roleColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Card(
                color: roleColors.surface,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.analytics,
                        color: roleColors.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Analytics',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: roleColors.onSurface,
                        ),
                      ),
                      Text(
                        '1,234',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: roleColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                color: roleColors.surface,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: roleColors.success,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Growth',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: roleColors.onSurface,
                        ),
                      ),
                      Text(
                        '+23%',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: roleColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildButtonsDemo() {
    final roleColors = RoleThemeManager.getCurrentColors();
    
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
              'Button Styles',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: roleColors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            
            // Primary Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: roleColors.primary,
                  foregroundColor: roleColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Primary Action',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Secondary Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: roleColors.primary,
                  side: BorderSide(color: roleColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Secondary Action',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Icon Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildIconButton(Icons.favorite, roleColors.error),
                _buildIconButton(Icons.share, roleColors.primary),
                _buildIconButton(Icons.bookmark, roleColors.warning),
                _buildIconButton(Icons.download, roleColors.success),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: () {},
        icon: Icon(icon, color: color),
        iconSize: 24,
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.supermarket:
        return const Color(0xFF2196F3); // Blue
      case UserRole.distributor:
        return const Color(0xFFFF5722); // Deep Orange
      case UserRole.delivery:
        return const Color(0xFF4CAF50); // Green
    }
  }

  String _getRoleString(UserRole role) {
    switch (role) {
      case UserRole.supermarket:
        return 'Supermarket';
      case UserRole.distributor:
        return 'Distributor';
      case UserRole.delivery:
        return 'Delivery';
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
        return 'Blue & Teal theme designed for retail operations. Features professional blues for trust and reliability, with teal accents for modern appeal.';
      case UserRole.distributor:
        return 'Orange & Deep Orange theme optimized for logistics operations. Warm oranges convey energy and efficiency, perfect for supply chain management.';
      case UserRole.delivery:
        return 'Green & Teal theme tailored for delivery services. Fresh greens represent movement and growth, ideal for transportation and logistics.';
    }
  }
}
