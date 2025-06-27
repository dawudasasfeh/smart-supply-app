import 'package:flutter/material.dart';

// Auth
import 'screens/login_page.dart';
import 'screens/signup_page.dart';

// Supermarket
import 'screens/supermarket/dashboard_page.dart';
import 'screens/supermarket/browseproduct_page.dart';
import 'screens/supermarket/cart_page.dart';
import 'screens/supermarket/orders_page.dart';
import 'screens/supermarket/inventory_page.dart';
import 'screens/supermarket/offers_page.dart';
import 'screens/supermarket/chat_page.dart';
import 'screens/supermarket/profile_page.dart';

// Distributor
import 'screens/distributor/dashboard_page.dart';
import 'screens/distributor/manageproducts_page.dart';
import 'screens/distributor/addproduct_page.dart';
import 'screens/distributor/editproduct_page.dart';
import 'screens/distributor/incomingorders_page.dart';
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
import 'screens/chat_list_page.dart';
import 'screens/addchat_page.dart';
import 'screens/qrgenerator_page.dart';
import 'screens/QRscan_page.dart';

void main() {
  runApp(const SupplyChainApp());
}

class SupplyChainApp extends StatelessWidget {
  const SupplyChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Supply Chain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
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
            return MaterialPageRoute(builder: (_) => const SupermarketDashboard());
          case '/browseProducts':
            return MaterialPageRoute(builder: (_) => const BrowseProductsPage());
         case '/cart':
            return MaterialPageRoute(builder: (_) => const CartPage());
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
          case '/supplierOrders':
            return MaterialPageRoute(builder: (_) => const SupplierOrdersPage());
          case '/manageOffers':
            return MaterialPageRoute(builder: (_) => const ManageOffersPage());
          case '/addOffer':
            if (args is Map<String, dynamic> && args.containsKey('productId')) {
              return MaterialPageRoute(
                builder: (_) => AddOfferPage(
                  productId: args['productId'],
                  productName: args['productName'],
                ),
              );
            }
            return _errorRoute('Missing product data for AddOfferPage');
          case '/supplierProfile':
            return MaterialPageRoute(builder: (_) => const SupplierProfilePage());
          case '/deliveryManagement':
            return MaterialPageRoute(builder: (_) => const DeliveryManagementPage());
          case '/assignedOrdersDetails':
            final deliveryId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => AssignedOrdersDetailsPage(deliveryId: deliveryId),
            );         // 🚚 Delivery
          case '/deliveryDashboard':
            return MaterialPageRoute(builder: (_) => const DeliveryDashboard());
          case '/assignedOrders':
            return MaterialPageRoute(builder: (_) => const AssignedOrdersPage());
          case '/deliveredOrders':
            return MaterialPageRoute(builder: (_) => const DeliveredOrdersPage());
          case '/deliveryProfile':
            return MaterialPageRoute(builder: (_) => const DeliveryProfilePage());

          // 💬 Chat
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


          // 📦 QR
          case '/qrGenerate':
            if (args is Map<String, dynamic> &&
                args.containsKey('orderId') &&
                args.containsKey('deliveryCode')) {
              return MaterialPageRoute(
                builder: (_) => QRGeneratorPage(
                  orderId: args['orderId'],
                  deliveryCode: args['deliveryCode'],
                ),
              );
            }
            return _errorRoute('Missing QR generation data');
          case '/qrScan':
            return MaterialPageRoute(builder: (_) => const QRScanPage());

          // ⚙️ Settings
          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsPage());
          
          default:
            return _errorRoute('Page not found: ${settings.name}');
        }
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
