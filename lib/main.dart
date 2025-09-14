import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Services
import 'services/socket_service.dart';

// Theme
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

// Auth
import 'screens/EditProfile_page.dart';
import 'screens/login_page.dart';
import 'screens/payment_Page.dart';
import 'screens/signup_page.dart';

// Supermarket
import 'screens/supermarket/browseproduct_page.dart';
import 'screens/supermarket/cart_page.dart';
import 'screens/supermarket/orders_page.dart';
import 'screens/supermarket/inventory_page.dart';
import 'screens/supermarket/offers_page.dart';
import 'screens/supermarket/supermarket_main.dart';
import 'screens/supermarket/chat_page.dart';
import 'screens/supermarket/profile_page.dart';

// Distributor
import 'screens/distributor/dashboard_page.dart';
import 'screens/distributor/manageproducts_page.dart';
import 'screens/distributor/addproduct_page.dart';
import 'screens/distributor/editproduct_page.dart';
import 'screens/distributor/incomingorders_page.dart';  // Note renamed import, ensure consistent
import 'screens/distributor/manageoffers_page.dart';
import 'screens/distributor/addoffer_page.dart';
import 'screens/distributor/chat_page.dart';
import 'screens/distributor/profile_page.dart';
import 'screens/distributor/deliverymanagement_page.dart';
import 'screens/distributor/AssignedOrdersDetails_page.dart';

// Delivery
import 'screens/delivery/dashboard_page.dart';
import 'screens/delivery/assignedorders_page.dart';
import 'screens/delivery/deliveredorders_page.dart';
import 'screens/delivery/profile_page.dart';

// Common
import 'screens/settings_page.dart';
import 'screens/enhanced_settings_page.dart';
import 'screens/chat/chat_list_page.dart';
import 'screens/chat/add_chat_page.dart';

// QR Code Authentication
import 'screens/qr_code/qr_generator_page.dart';
import 'screens/qr_code/qr_scanner_page.dart';
import 'screens/analytics_dashboard.dart';
import 'screens/rating_system_page.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Smart Supply Chain',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          initialRoute: '/',
          navigatorObservers: [routeObserver],
          onGenerateRoute: (settings) {
        final args = settings.arguments;

        switch (settings.name) {
          // 🔐 Auth
          case '/':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupPage());

          // 🏪 Supermarket
          case '/supermarketDashboard':
            return MaterialPageRoute(builder: (_) => const SuperMarketMain());
          case '/browseProducts':
            return MaterialPageRoute(builder: (_) => const BrowseProductsPage());
          case '/cart':
            return MaterialPageRoute(builder: (_) => const CartPage());
          case '/orderHistory':
            return MaterialPageRoute(builder: (_) => const OrdersPage());
          case '/inventory':
            return MaterialPageRoute(builder: (_) => const InventoryPage());
          case '/offers':
            return MaterialPageRoute(builder: (_) => const OffersPage());
          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfilePage());

          // 🟨 Distributor
          case '/distributorDashboard':
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
            return MaterialPageRoute(builder: (_) => const SupplierOrdersPage());
          case '/manageOffers':
            return MaterialPageRoute(builder: (_) => const ManageOffersPage());
          case '/addOffer':
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => AddOfferPage(
                  productId: args['productId'],
                  productName: args['productName'],
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
          
          // ⚙️ Settings
          case '/settings':
            return MaterialPageRoute(builder: (_) => const EnhancedSettingsPage());
          case '/settingsOld':
            return MaterialPageRoute(builder: (_) => const SettingsPage());

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
