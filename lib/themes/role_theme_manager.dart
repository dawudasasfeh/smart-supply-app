import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum UserRole { supermarket, distributor, delivery }

class RoleThemeManager {
  static UserRole _currentRole = UserRole.supermarket;
  
  static void setUserRole(String role) {
    switch (role.toLowerCase()) {
      case 'supermarket':
        _currentRole = UserRole.supermarket;
        break;
      case 'distributor':
        _currentRole = UserRole.distributor;
        break;
      case 'delivery':
        _currentRole = UserRole.delivery;
        break;
      default:
        _currentRole = UserRole.supermarket;
    }
  }
  
  static UserRole get currentRole => _currentRole;
  
  // Get current theme based on role
  static ThemeData getCurrentTheme({bool isDark = false}) {
    switch (_currentRole) {
      case UserRole.supermarket:
        return getSupermarketTheme(isDark: isDark);
      case UserRole.distributor:
        return getDistributorTheme(isDark: isDark);
      case UserRole.delivery:
        return getDeliveryTheme(isDark: isDark);
    }
  }
  
  // Get current color scheme
  static RoleColorScheme getCurrentColors({bool isDark = false}) {
    switch (_currentRole) {
      case UserRole.supermarket:
        return SupermarketColors(isDark: isDark);
      case UserRole.distributor:
        return DistributorColors(isDark: isDark);
      case UserRole.delivery:
        return DeliveryColors(isDark: isDark);
    }
  }
  
  // Supermarket Theme - Blue & Teal
  static ThemeData getSupermarketTheme({bool isDark = false}) {
    final colors = SupermarketColors(isDark: isDark);
    
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primarySwatch: Colors.blue,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: colors.primary,
        secondary: colors.secondary,
        surface: colors.surface,
        background: colors.background,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ),
    );
  }
  
  // Distributor Theme - Orange & Deep Orange
  static ThemeData getDistributorTheme({bool isDark = false}) {
    final colors = DistributorColors(isDark: isDark);
    
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primarySwatch: Colors.deepOrange,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: colors.primary,
        secondary: colors.secondary,
        surface: colors.surface,
        background: colors.background,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ),
    );
  }
  
  // Delivery Theme - Green & Teal
  static ThemeData getDeliveryTheme({bool isDark = false}) {
    final colors = DeliveryColors(isDark: isDark);
    
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primarySwatch: Colors.green,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: colors.primary,
        secondary: colors.secondary,
        surface: colors.surface,
        background: colors.background,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ),
    );
  }
}

// Base color scheme class
abstract class RoleColorScheme {
  Color get primary;
  Color get secondary;
  Color get accent;
  Color get background;
  Color get surface;
  Color get onSurface;
  Color get onPrimary;
  Color get success;
  Color get warning;
  Color get error;
  Color get info;
  Color get outline;
  
  // Gradient colors
  List<Color> get primaryGradient;
  List<Color> get secondaryGradient;
  List<Color> get backgroundGradient;
}

// Supermarket Colors - Blue & Teal Theme
class SupermarketColors extends RoleColorScheme {
  final bool isDark;
  
  SupermarketColors({this.isDark = false});
  
  @override
  Color get primary => isDark ? const Color(0xFF1976D2) : const Color(0xFF2196F3);
  
  @override
  Color get secondary => isDark ? const Color(0xFF00695C) : const Color(0xFF009688);
  
  @override
  Color get accent => isDark ? const Color(0xFF03DAC6) : const Color(0xFF00BCD4);
  
  @override
  Color get background => isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
  
  @override
  Color get surface => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  
  @override
  Color get onSurface => isDark ? Colors.white : const Color(0xFF2C3E50);
  
  @override
  Color get onPrimary => Colors.white;
  
  @override
  Color get success => const Color(0xFF4CAF50);
  
  @override
  Color get warning => const Color(0xFFFF9800);
  
  @override
  Color get error => const Color(0xFFF44336);
  
  @override
  Color get info => const Color(0xFF2196F3);
  
  @override
  Color get outline => isDark ? Colors.grey[600]! : Colors.grey[400]!;
  
  @override
  List<Color> get primaryGradient => [
    primary,
    primary.withOpacity(0.8),
  ];
  
  @override
  List<Color> get secondaryGradient => [
    secondary,
    accent,
  ];
  
  @override
  List<Color> get backgroundGradient => [
    background,
    background.withOpacity(0.8),
  ];
}

// Distributor Colors - Orange & Deep Orange Theme
class DistributorColors extends RoleColorScheme {
  final bool isDark;
  
  DistributorColors({this.isDark = false});
  
  @override
  Color get primary => isDark ? const Color(0xFFD84315) : const Color(0xFFFF5722);
  
  @override
  Color get secondary => isDark ? const Color(0xFFE65100) : const Color(0xFFFF9800);
  
  @override
  Color get accent => isDark ? const Color(0xFFFFAB40) : const Color(0xFFFFB74D);
  
  @override
  Color get background => isDark ? const Color(0xFF121212) : const Color(0xFFFFF8F5);
  
  @override
  Color get surface => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  
  @override
  Color get onSurface => isDark ? Colors.white : const Color(0xFF3E2723);
  
  @override
  Color get onPrimary => Colors.white;
  
  @override
  Color get success => const Color(0xFF4CAF50);
  
  @override
  Color get warning => const Color(0xFFFF9800);
  
  @override
  Color get error => const Color(0xFFF44336);
  
  @override
  Color get info => const Color(0xFFFF5722);
  
  @override
  Color get outline => isDark ? Colors.grey[600]! : Colors.grey[400]!;
  
  @override
  List<Color> get primaryGradient => [
    primary,
    secondary,
  ];
  
  @override
  List<Color> get secondaryGradient => [
    secondary,
    accent,
  ];
  
  @override
  List<Color> get backgroundGradient => [
    background,
    background.withOpacity(0.8),
  ];
}

// Delivery Colors - Green & Teal Theme
class DeliveryColors extends RoleColorScheme {
  final bool isDark;
  
  DeliveryColors({this.isDark = false});
  
  @override
  Color get primary => isDark ? const Color(0xFF2E7D32) : const Color(0xFF4CAF50);
  
  @override
  Color get secondary => isDark ? const Color(0xFF00695C) : const Color(0xFF009688);
  
  @override
  Color get accent => isDark ? const Color(0xFF64FFDA) : const Color(0xFF26A69A);
  
  @override
  Color get background => isDark ? const Color(0xFF121212) : const Color(0xFFF1F8E9);
  
  @override
  Color get surface => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  
  @override
  Color get onSurface => isDark ? Colors.white : const Color(0xFF1B5E20);
  
  @override
  Color get onPrimary => Colors.white;
  
  @override
  Color get success => const Color(0xFF4CAF50);
  
  @override
  Color get warning => const Color(0xFFFF9800);
  
  @override
  Color get error => const Color(0xFFF44336);
  
  @override
  Color get info => const Color(0xFF4CAF50);
  
  @override
  Color get outline => isDark ? Colors.grey[600]! : Colors.grey[400]!;
  
  @override
  List<Color> get primaryGradient => [
    primary,
    secondary,
  ];
  
  @override
  List<Color> get secondaryGradient => [
    secondary,
    accent,
  ];
  
  @override
  List<Color> get backgroundGradient => [
    background,
    background.withOpacity(0.8),
  ];
}

// Theme extension for easy access to role colors
extension RoleThemeExtension on BuildContext {
  RoleColorScheme get roleColors => RoleThemeManager.getCurrentColors(
    isDark: Theme.of(this).brightness == Brightness.dark,
  );
  
  UserRole get userRole => RoleThemeManager.currentRole;
}
