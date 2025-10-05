import 'package:flutter/material.dart';
import '../themes/role_theme_manager.dart';

/// Role-aware color system that adapts to the current user role
/// This provides backward compatibility with existing AppColors usage
/// while enabling role-specific theming
class RoleAwareColors {
  static RoleColorScheme get _currentColors => RoleThemeManager.getCurrentColors();
  
  // Primary Colors - Role Adaptive
  static Color get primary => _currentColors.primary;
  static Color get secondary => _currentColors.secondary;
  static Color get accent => _currentColors.accent;
  
  // Background Colors - Role Adaptive
  static Color get background => _currentColors.background;
  static Color get surface => _currentColors.surface;
  static Color get onSurface => _currentColors.onSurface;
  static Color get onPrimary => _currentColors.onPrimary;
  
  // Status Colors - Universal
  static Color get success => _currentColors.success;
  static Color get warning => _currentColors.warning;
  static Color get error => _currentColors.error;
  static Color get info => _currentColors.info;
  
  // Gradients - Role Adaptive
  static List<Color> get primaryGradient => _currentColors.primaryGradient;
  static List<Color> get secondaryGradient => _currentColors.secondaryGradient;
  static List<Color> get backgroundGradient => _currentColors.backgroundGradient;
  
  // Text Colors - Adaptive to theme
  static Color get textPrimary => onSurface;
  static Color get textSecondary => onSurface.withOpacity(0.7);
  static Color get textTertiary => onSurface.withOpacity(0.5);
  static Color get textInverse => Colors.white;
  
  // Border Colors - Adaptive
  static Color get border => onSurface.withOpacity(0.12);
  static Color get borderLight => onSurface.withOpacity(0.08);
  static Color get borderDark => onSurface.withOpacity(0.2);
  
  // Shadow Colors - Universal
  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowDark = Color(0x33000000);
  
  // Card Colors - Adaptive
  static Color get cardBackground => surface;
  static Color get cardBackgroundVariant => surface.withOpacity(0.8);
  
  // Button Colors - Role Adaptive
  static Color get buttonPrimary => primary;
  static Color get buttonSecondary => surface;
  static Color get buttonText => onPrimary;
  static Color get buttonTextSecondary => textPrimary;
  
  // Input Colors - Adaptive
  static Color get inputBackground => surface;
  static Color get inputBorder => border;
  static Color get inputBorderFocused => primary;
  static Color get inputBorderError => error;
  static Color get inputText => textPrimary;
  static Color get inputHint => textSecondary;
  static Color get inputLabel => textSecondary;
  
  // App Bar Colors - Role Adaptive
  static Color get appBarBackground => primary;
  static Color get appBarForeground => onPrimary;
  
  // Bottom Navigation Colors - Role Adaptive
  static Color get bottomNavBackground => surface;
  static Color get bottomNavSelected => primary;
  static Color get bottomNavUnselected => textSecondary;
  
  // Floating Action Button Colors - Role Adaptive
  static Color get fabBackground => primary;
  static Color get fabForeground => onPrimary;
  
  // Snackbar Colors - Adaptive
  static Color get snackbarBackground => textPrimary;
  static Color get snackbarForeground => textInverse;
  static Color get snackbarSuccess => success;
  static Color get snackbarWarning => warning;
  static Color get snackbarError => error;
  static Color get snackbarInfo => info;
  
  // Status Colors for Orders - Universal
  static Color get orderPending => warning;
  static Color get orderProcessing => info;
  static Color get orderCompleted => success;
  static Color get orderCancelled => error;
  
  // Status Colors for Stock - Universal
  static Color get stockHigh => success;
  static Color get stockMedium => warning;
  static Color get stockLow => error;
  static const Color stockOut = Color(0xFF6B7280);
  
  // Priority Colors - Universal
  static Color get priorityHigh => error;
  static Color get priorityMedium => warning;
  static Color get priorityLow => success;
  
  // Chart Colors - Role Adaptive
  static List<Color> get chartColors => [
    primary,
    success,
    warning,
    error,
    info,
    secondary,
    const Color(0xFF8B5CF6),
    const Color(0xFF06B6D4),
    const Color(0xFF84CC16),
    const Color(0xFFF97316),
  ];
  
  // Overlay Colors - Universal
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);
  
  // Disabled Colors - Adaptive
  static Color get disabled => onSurface.withOpacity(0.38);
  static Color get disabledBackground => surface.withOpacity(0.12);
  
  // Focus Colors - Role Adaptive
  static Color get focus => primary;
  static Color get focusRing => primary.withOpacity(0.12);
  
  // Hover Colors - Adaptive
  static const Color hover = Color(0x0A000000);
  static Color get hoverPrimary => primary.withOpacity(0.08);
  
  // Selection Colors - Role Adaptive
  static Color get selection => primary.withOpacity(0.12);
  static Color get selectionBackground => primary.withOpacity(0.08);
  
  // Divider Colors - Adaptive
  static Color get divider => border;
  static Color get dividerLight => borderLight;
  
  // Dialog Colors - Adaptive
  static Color get dialogBackground => surface;
  static const Color dialogOverlay = overlay;
  
  // List Tile Colors - Adaptive
  static Color get listTileBackground => surface;
  static const Color listTileHover = hover;
  static Color get listTileSelected => selectionBackground;
  
  // Chip Colors - Adaptive
  static Color get chipBackground => surface.withOpacity(0.8);
  static Color get chipSelected => primary;
  static Color get chipText => textPrimary;
  static Color get chipTextSelected => onPrimary;
  
  // Badge Colors - Role Adaptive
  static Color get badgeBackground => error;
  static Color get badgeText => textInverse;
  
  // Progress Colors - Role Adaptive
  static Color get progressBackground => surface.withOpacity(0.8);
  static Color get progressValue => primary;
  static Color get progressValueSuccess => success;
  static Color get progressValueWarning => warning;
  static Color get progressValueError => error;
  
  // Switch Colors - Role Adaptive
  static Color get switchActive => primary;
  static Color get switchInactive => disabled;
  static Color get switchThumb => surface;
  
  // Slider Colors - Role Adaptive
  static Color get sliderActive => primary;
  static Color get sliderInactive => disabled;
  static Color get sliderThumb => surface;
  
  // Checkbox Colors - Role Adaptive
  static Color get checkboxActive => primary;
  static Color get checkboxInactive => disabled;
  static Color get checkboxCheck => onPrimary;
  
  // Radio Colors - Role Adaptive
  static Color get radioActive => primary;
  static Color get radioInactive => disabled;
  static Color get radioDot => onPrimary;
  
  // Tab Colors - Role Adaptive
  static Color get tabSelected => primary;
  static Color get tabUnselected => textSecondary;
  static Color get tabIndicator => primary;
  
  // Stepper Colors - Role Adaptive
  static Color get stepperActive => primary;
  static Color get stepperInactive => disabled;
  static Color get stepperCompleted => success;
  static Color get stepperError => error;
  
  // Tooltip Colors - Adaptive
  static Color get tooltipBackground => textPrimary;
  static Color get tooltipText => textInverse;
  
  // Backdrop Colors - Universal
  static const Color backdrop = overlay;
  static const Color backdropLight = overlayLight;
  
  // Splash Colors - Role Adaptive
  static Color get splash => primary.withOpacity(0.12);
  static Color get splashPrimary => primary.withOpacity(0.12);
  
  // Ripple Colors - Adaptive
  static const Color ripple = Color(0x1A000000);
  static Color get ripplePrimary => primary.withOpacity(0.12);
  
  // Highlight Colors - Role Adaptive
  static Color get highlight => primary.withOpacity(0.12);
  static Color get highlightPrimary => primary.withOpacity(0.12);
  
  // Elevation Colors - Universal
  static const Color elevation1 = Color(0x1A000000);
  static const Color elevation2 = Color(0x1F000000);
  static const Color elevation3 = Color(0x24000000);
  static const Color elevation4 = Color(0x29000000);
  static const Color elevation5 = Color(0x2E000000);
  
  // Helper methods for role-specific styling
  static LinearGradient get primaryLinearGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: primaryGradient,
  );
  
  static LinearGradient get secondaryLinearGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: secondaryGradient,
  );
  
  static LinearGradient get backgroundLinearGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: backgroundGradient,
  );
  
  // Role-specific color schemes for easy access
  static bool get isSupermarketTheme => RoleThemeManager.currentRole == UserRole.supermarket;
  static bool get isDistributorTheme => RoleThemeManager.currentRole == UserRole.distributor;
  static bool get isDeliveryTheme => RoleThemeManager.currentRole == UserRole.delivery;
  
  // Get role-specific accent colors
  static Color get roleAccent {
    switch (RoleThemeManager.currentRole) {
      case UserRole.supermarket:
        return const Color(0xFF00BCD4); // Cyan
      case UserRole.distributor:
        return const Color(0xFFFFB74D); // Orange
      case UserRole.delivery:
        return const Color(0xFF26A69A); // Teal
    }
  }
  
  // Get role name for UI display
  static String get roleName {
    switch (RoleThemeManager.currentRole) {
      case UserRole.supermarket:
        return 'Supermarket';
      case UserRole.distributor:
        return 'Distributor';
      case UserRole.delivery:
        return 'Delivery';
    }
  }
  
  // Get role icon
  static IconData get roleIcon {
    switch (RoleThemeManager.currentRole) {
      case UserRole.supermarket:
        return Icons.store;
      case UserRole.distributor:
        return Icons.local_shipping;
      case UserRole.delivery:
        return Icons.delivery_dining;
    }
  }
}
