import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Services
import 'services/socket_service.dart';

// Theme
import 'theme/theme_provider.dart';
import 'themes/role_theme_manager.dart';

// Localization
import 'l10n/language_provider.dart';
import 'l10n/app_localizations.dart';

// Auth
import 'screens/EditProfile_page.dart';
import 'screens/login_page.dart';
import 'screens/payment_Page.dart';
import 'screens/signup_page.dart';

// Supermarket
import 'screens/SuperMarket/BrowseProduct_Page.dart';
import 'screens/SuperMarket/Cart_Page.dart';
import 'screens/SuperMarket/Inventory_Page.dart';
import 'screens/SuperMarket/Offers_Page.dart';
import 'screens/SuperMarket/profile_page_final.dart';
import 'screens/SuperMarket/SuperMarket_Main.dart';
import 'screens/SuperMarket/Chat_Page.dart';

// Distributor
import 'screens/distributor/dashboard_page.dart';
import 'screens/Distributor/Distributor_Main.dart';
import 'screens/distributor/manageproducts_page.dart';
import 'screens/distributor/addproduct_page.dart';
import 'screens/distributor/editproduct_page.dart';
import 'screens/Distributor/IncomingOrders_Page.dart';
import 'screens/distributor/manageoffers_page.dart';
import 'screens/distributor/addoffer_page.dart';
import 'screens/distributor/chat_page.dart';
import 'screens/distributor/profile_page.dart';
import 'screens/Distributor/DeliveryManagement_Page.dart';
import 'screens/distributor/AssignedOrdersDetails_page.dart';
import 'screens/distributor/deliverytracking_page.dart';
import 'screens/distributor/deliveryanalytics_page.dart';
import 'screens/demo/role_theme_demo.dart';
import 'screens/demo/dashboard_theme_showcase.dart';
// Smart Assignment - Removed old system, now integrated in distributor dashboard

// Delivery
import 'screens/delivery/dashboard_page.dart';
import 'screens/delivery/assignedorders_page.dart';
import 'screens/delivery/deliveredorders_page.dart';
import 'screens/delivery/profile_page.dart';

// Common
import 'screens/common/enhanced_settings_page.dart';
import 'screens/chat/chat_list_page.dart';
import 'screens/chat/add_chat_page.dart';

// QR Code Authentication
import 'screens/qr_code/qr_generator_page.dart';
import 'screens/qr_code/qr_scanner_page.dart';
import 'screens/analytics_dashboard.dart';
import 'screens/rating_system_page.dart';
import 'screens/payment/payment_page.dart';
import 'screens/payment/payment_methods_page.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const SupplyChainApp(),
    ),
  );
}

class SupplyChainApp extends StatefulWidget {
  const SupplyChainApp({super.key});

  @override
  State<SupplyChainApp> createState() => _SupplyChainAppState();
}

class _SupplyChainAppState extends State<SupplyChainApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize Socket.IO connection
    SocketService.instance.connect();
    // Initialize role-based theming
    _initializeRoleTheme();
  }
  
  Future<void> _initializeRoleTheme() async {
    // Get user role from SharedPreferences and set theme
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('role') ?? 'supermarket';
      RoleThemeManager.setUserRole(userRole);
      if (mounted) {
        setState(() {}); // Trigger rebuild with new theme
      }
    } catch (e) {
      print('Error initializing role theme: $e');
      // Default to supermarket theme
      RoleThemeManager.setUserRole('supermarket');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SocketService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        SocketService.instance.connect();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        SocketService.instance.disconnect();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        return MaterialApp(
          title: 'Smart Supply Chain',
          debugShowCheckedModeBanner: false,
          
          // Localization
          locale: languageProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('ar', ''),
          ],
          
          // Theme
          theme: RoleThemeManager.getCurrentTheme(isDark: false),
          darkTheme: RoleThemeManager.getCurrentTheme(isDark: true),
          themeMode: themeProvider.themeMode,
          
          // Navigation
          initialRoute: '/',
          navigatorObservers: [routeObserver],
          onGenerateRoute: (settings) {
        final args = settings.arguments;

        switch (settings.name) {
          // 🔐 Auth
          case '/':
            return MaterialPageRoute(builder: (_) => const SignupPage());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupPage());

          // 🏪 Supermarket
          case '/supermarket':
            if (args is Map<String, dynamic> && args.containsKey('initialIndex')) {
              return MaterialPageRoute(
                builder: (_) => SuperMarketMain(initialIndex: args['initialIndex']),
              );
            }
            return MaterialPageRoute(builder: (_) => const SuperMarketMain());
          case '/supermarketDashboard':
            return MaterialPageRoute(builder: (_) => const SuperMarketMain());
          case '/browseProducts':
            return MaterialPageRoute(builder: (_) => const BrowseProductsPage());
          case '/cart':
            return MaterialPageRoute(builder: (_) => const CartPage());
          case '/orderHistory':
            return MaterialPageRoute(builder: (_) => const SuperMarketMain(initialIndex: 2));
          case '/inventory':
            return MaterialPageRoute(builder: (_) => const InventoryPage());
          case '/offers':
            return MaterialPageRoute(builder: (_) => const OffersPage());
          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfilePage());

          // 🟨 Distributor
          case '/distributorDashboard':
            return MaterialPageRoute(builder: (_) => const DistributorMain());
          case '/distributor':
            if (args is Map<String, dynamic> && args.containsKey('initialIndex')) {
              return MaterialPageRoute(
                builder: (_) => DistributorMain(initialIndex: args['initialIndex']),
              );
            }
            return MaterialPageRoute(builder: (_) => const DistributorMain());
          case '/smartAssignment':
            // Smart assignment is now integrated in the distributor dashboard
            return MaterialPageRoute(builder: (_) => const DistributorDashboard());
          case '/manageProducts':
            return MaterialPageRoute(builder: (_) => const ManageProductsPage());
          case '/addProduct':
            return MaterialPageRoute(builder: (_) => const AddProductPage());
          case '/editProduct':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(builder: (_) => EditProductPage(product: args));
            }
            return _errorRoute('Missing product data for EditProductPage');
          case '/supplierOrders': // renamed to match import
            return MaterialPageRoute(builder: (_) => const IncomingOrdersPage());
          case '/manageOffers':
            return MaterialPageRoute(builder: (_) => const ManageOffersPage());
          case '/addOffer':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => AddOfferPage(
                  productId: args['productId'],
                  productName: args['productName'],
                  originalPrice: args['originalPrice'],
                  productImage: args['productImage'],
                ),
              );
            }
            return _errorRoute('Missing product data for AddOfferPage');
          case '/supplierProfile':
            return MaterialPageRoute(builder: (_) => const DistributorProfilePage());
          case '/deliveryManagement':
            return MaterialPageRoute(builder: (_) => const DeliveryManagementPage());
          case '/assignedOrdersDetails':
            if (args is int) {
              return MaterialPageRoute(
                builder: (_) => AssignedOrdersDetailsPage(deliveryId: args),
              );
            }
            return _errorRoute('Missing deliveryId for AssignedOrdersDetailsPage');
          case '/deliveryTracking':
            return MaterialPageRoute(
              builder: (_) => const DeliveryTrackingPage(),
            );
          case '/deliveryAnalytics':
            return MaterialPageRoute(
              builder: (_) => const DeliveryAnalyticsPage(),
            );

          // 🚚 Delivery
          case '/deliveryDashboard':
            return MaterialPageRoute(builder: (_) => const DeliveryDashboard());
          case '/assignedOrders':
            return MaterialPageRoute(builder: (_) => const AssignedOrdersPage());
          case '/deliveredOrders':
            return MaterialPageRoute(builder: (_) => const DeliveredOrdersPage());
          case '/deliveryProfile':
            return MaterialPageRoute(builder: (_) => const DeliveryProfilePage());
          case '/editProfile':
            return MaterialPageRoute(builder: (_) => const EditProfilePage(role: ''));

          // 💬 Chat (New Socket.IO System)
          case '/chatList':
            if (args is Map<String, dynamic> && args.containsKey('role')) {
              return MaterialPageRoute(
                builder: (_) => ChatListPage(role: args['role']),
              );
            }
            return _errorRoute('Missing role for ChatListPage');
          case '/addchat':
            if (args is Map<String, dynamic> && args.containsKey('role')) {
              return MaterialPageRoute(
                builder: (_) => AddChatPage(role: args['role']),
              );
            }
            return _errorRoute('Missing role for AddChatPage');
          
          // Legacy chat routes (kept for backward compatibility)
          case '/chat':
            if (args is Map<String, dynamic> && args.containsKey('distributorId')) {
              return MaterialPageRoute(
                builder: (_) => ChatPage(distributorId: args['distributorId']),
              );
            }
            return _errorRoute('Missing distributorId for ChatPage');
          case '/supplierChat':
            if (args is Map<String, dynamic> && args.containsKey('supermarketId')) {
              return MaterialPageRoute(
                builder: (_) => SupplierChatPage(supermarketId: args['supermarketId']),
              );
            }
            return _errorRoute('Missing supermarketId for SupplierChatPage');

          // 📦 QR Code Authentication
          case '/qrGenerator':
            return MaterialPageRoute(builder: (_) => const QRGeneratorPage());
          case '/qrScanner':
            return MaterialPageRoute(builder: (_) => const QRScannerPage());
          case '/paymentSettings':
            return MaterialPageRoute(builder: (_) => const PaymentSettingsPage());
          // 📊 Analytics
          case '/analytics':
            return MaterialPageRoute(builder: (_) => const AnalyticsDashboard());
          
          // ⭐ Rating System
          case '/rating':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => RatingSystemPage(
                  userRole: args['userRole'] ?? 'supermarket',
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const RatingSystemPage(userRole: 'supermarket'),
            );
          
          // 💳 Payment System
          case '/payment':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => PaymentPage(
                  order: args['order'],
                  totalAmount: args['totalAmount'],
                  items: args['items'],
                ),
              );
            }
            return _errorRoute('Missing payment data');
          case '/paymentMethods':
            return MaterialPageRoute(builder: (_) => const PaymentMethodsPage());
          
          // ⚙️ Settings
          case '/settings':
            return MaterialPageRoute(builder: (_) => const EnhancedSettingsPage());
          // Removed old settings route

          // 🎨 Theme Demo
          case '/themeDemo':
            return MaterialPageRoute(builder: (_) => const RoleThemeDemo());
          case '/dashboardShowcase':
            return MaterialPageRoute(builder: (_) => const DashboardThemeShowcase());

          default:
            return _errorRoute('Page not found: ${settings.name}');
        }
      },
        );
      },
    );
  }

  Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Text(message)),
      ),
    );
  }
}
