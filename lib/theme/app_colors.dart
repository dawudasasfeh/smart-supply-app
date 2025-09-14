import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF667EEA);
  static const Color primaryDark = Color(0xFF764BA2);
  static const Color primaryLight = Color(0xFF8B9AFF);
  
  // Legacy colors for compatibility
  static const Color accent = Color(0xFFF093FB);
  
  // Secondary Colors
  static const Color secondary = Color(0xFFF093FB);
  static const Color secondaryDark = Color(0xFFF5576C);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);
  
  // Neutral Colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textInverse = Color(0xFFFFFFFF);
  
  // Border Colors
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderDark = Color(0xFFCBD5E1);
  
  // Shadow Colors
  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowDark = Color(0x33000000);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
  
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, successLight],
  );
  
  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warning, warningLight],
  );
  
  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [error, errorLight],
  );
  
  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [info, infoLight],
  );
  
  // Chart Colors
  static const List<Color> chartColors = [
    primary,
    success,
    warning,
    error,
    info,
    secondary,
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
    Color(0xFFF97316),
  ];
  
  // Priority Colors
  static const Color priorityHigh = error;
  static const Color priorityMedium = warning;
  static const Color priorityLow = success;
  
  // Status Colors for Orders
  static const Color orderPending = warning;
  static const Color orderProcessing = info;
  static const Color orderCompleted = success;
  static const Color orderCancelled = error;
  
  // Status Colors for Stock
  static const Color stockHigh = success;
  static const Color stockMedium = warning;
  static const Color stockLow = error;
  static const Color stockOut = Color(0xFF6B7280);
  
  // Background Colors for Cards
  static const Color cardBackground = surface;
  static const Color cardBackgroundVariant = surfaceVariant;
  
  // Overlay Colors
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);
  
  // Disabled Colors
  static const Color disabled = Color(0xFF94A3B8);
  static const Color disabledBackground = Color(0xFFF1F5F9);
  
  // Focus Colors
  static const Color focus = primary;
  static const Color focusRing = Color(0x1A667EEA);
  
  // Hover Colors
  static const Color hover = Color(0x0A000000);
  static const Color hoverPrimary = Color(0x1A667EEA);
  
  // Selection Colors
  static const Color selection = Color(0x1A667EEA);
  static const Color selectionBackground = Color(0x0A667EEA);
  
  // Divider Colors
  static const Color divider = border;
  static const Color dividerLight = borderLight;
  
  // App Bar Colors
  static const Color appBarBackground = surface;
  static const Color appBarForeground = textPrimary;
  
  // Bottom Navigation Colors
  static const Color bottomNavBackground = surface;
  static const Color bottomNavSelected = primary;
  static const Color bottomNavUnselected = textSecondary;
  
  // Floating Action Button Colors
  static const Color fabBackground = primary;
  static const Color fabForeground = textInverse;
  
  // Snackbar Colors
  static const Color snackbarBackground = textPrimary;
  static const Color snackbarForeground = textInverse;
  static const Color snackbarSuccess = success;
  static const Color snackbarWarning = warning;
  static const Color snackbarError = error;
  static const Color snackbarInfo = info;
  
  // Dialog Colors
  static const Color dialogBackground = surface;
  static const Color dialogOverlay = overlay;
  
  // List Tile Colors
  static const Color listTileBackground = surface;
  static const Color listTileHover = hover;
  static const Color listTileSelected = selectionBackground;
  
  // Input Field Colors
  static const Color inputBackground = surface;
  static const Color inputBorder = border;
  static const Color inputBorderFocused = focus;
  static const Color inputBorderError = error;
  static const Color inputText = textPrimary;
  static const Color inputHint = textSecondary;
  static const Color inputLabel = textSecondary;
  
  // Button Colors
  static const Color buttonPrimary = primary;
  static const Color buttonPrimaryHover = primaryDark;
  static const Color buttonSecondary = surface;
  static const Color buttonSecondaryHover = surfaceVariant;
  static const Color buttonText = textInverse;
  static const Color buttonTextSecondary = textPrimary;
  
  // Chip Colors
  static const Color chipBackground = surfaceVariant;
  static const Color chipSelected = primary;
  static const Color chipText = textPrimary;
  static const Color chipTextSelected = textInverse;
  
  // Badge Colors
  static const Color badgeBackground = error;
  static const Color badgeText = textInverse;
  
  // Progress Colors
  static const Color progressBackground = surfaceVariant;
  static const Color progressValue = primary;
  static const Color progressValueSuccess = success;
  static const Color progressValueWarning = warning;
  static const Color progressValueError = error;
  
  // Switch Colors
  static const Color switchActive = primary;
  static const Color switchInactive = disabled;
  static const Color switchThumb = surface;
  
  // Slider Colors
  static const Color sliderActive = primary;
  static const Color sliderInactive = disabled;
  static const Color sliderThumb = surface;
  
  // Checkbox Colors
  static const Color checkboxActive = primary;
  static const Color checkboxInactive = disabled;
  static const Color checkboxCheck = textInverse;
  
  // Radio Colors
  static const Color radioActive = primary;
  static const Color radioInactive = disabled;
  static const Color radioDot = textInverse;
  
  // Tab Colors
  static const Color tabSelected = primary;
  static const Color tabUnselected = textSecondary;
  static const Color tabIndicator = primary;
  
  // Stepper Colors
  static const Color stepperActive = primary;
  static const Color stepperInactive = disabled;
  static const Color stepperCompleted = success;
  static const Color stepperError = error;
  
  // Tooltip Colors
  static const Color tooltipBackground = textPrimary;
  static const Color tooltipText = textInverse;
  
  // Backdrop Colors
  static const Color backdrop = overlay;
  static const Color backdropLight = overlayLight;
  
  // Splash Colors
  static const Color splash = Color(0x1A667EEA);
  static const Color splashPrimary = Color(0x1A667EEA);
  
  // Ripple Colors
  static const Color ripple = Color(0x1A000000);
  static const Color ripplePrimary = Color(0x1A667EEA);
  
  // Highlight Colors
  static const Color highlight = Color(0x1A667EEA);
  static const Color highlightPrimary = Color(0x1A667EEA);
  
  // Elevation Colors
  static const Color elevation1 = Color(0x1A000000);
  static const Color elevation2 = Color(0x1F000000);
  static const Color elevation3 = Color(0x24000000);
  static const Color elevation4 = Color(0x29000000);
  static const Color elevation5 = Color(0x2E000000);
  
  // Material 3 Colors
  static const Color material3Primary = Color(0xFF6750A4);
  static const Color material3OnPrimary = Color(0xFFFFFFFF);
  static const Color material3PrimaryContainer = Color(0xFFEADDFF);
  static const Color material3OnPrimaryContainer = Color(0xFF21005D);
  
  static const Color material3Secondary = Color(0xFF625B71);
  static const Color material3OnSecondary = Color(0xFFFFFFFF);
  static const Color material3SecondaryContainer = Color(0xFFE8DEF8);
  static const Color material3OnSecondaryContainer = Color(0xFF1D192B);
  
  static const Color material3Tertiary = Color(0xFF7D5260);
  static const Color material3OnTertiary = Color(0xFFFFFFFF);
  static const Color material3TertiaryContainer = Color(0xFFFFD8E4);
  static const Color material3OnTertiaryContainer = Color(0xFF31111D);
  
  static const Color material3Error = Color(0xFFBA1A1A);
  static const Color material3OnError = Color(0xFFFFFFFF);
  static const Color material3ErrorContainer = Color(0xFFFFDAD6);
  static const Color material3OnErrorContainer = Color(0xFF410002);
  
  static const Color material3Surface = Color(0xFFFFFBFE);
  static const Color material3OnSurface = Color(0xFF1C1B1F);
  static const Color material3SurfaceVariant = Color(0xFFE7E0EC);
  static const Color material3OnSurfaceVariant = Color(0xFF49454F);
  
  static const Color material3Outline = Color(0xFF79747E);
  static const Color material3OutlineVariant = Color(0xFFCAC4D0);
  
  static const Color material3Shadow = Color(0xFF000000);
  static const Color material3Scrim = Color(0xFF000000);
  static const Color material3InverseSurface = Color(0xFF313033);
  static const Color material3OnInverseSurface = Color(0xFFF4EFF4);
  static const Color material3InversePrimary = Color(0xFFD0BCFF);
  static const Color material3InverseOnSurface = Color(0xFF313033);
}