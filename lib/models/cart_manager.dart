import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CartManager {
  static final CartManager _instance = CartManager._internal();
  final Map<String, Map<String, dynamic>> _cart = {};
  
  factory CartManager() {
    return _instance;
  }

  CartManager._internal();

  bool get isEmpty => _cart.isEmpty;
  
  Map<String, Map<String, dynamic>> get items => Map.from(_cart);
  
  Map<int, List<Map<String, dynamic>>> get distributorItems {
    final Map<int, List<Map<String, dynamic>>> grouped = {};
    _cart.forEach((productId, item) {
      final distributorId = item['distributor_id'] as int?;
      if (distributorId != null) {
        grouped.putIfAbsent(distributorId, () => []);
        grouped[distributorId]!.add({
          'id': productId,
          ...item,
        });
      }
    });
    return grouped;
  }

  void addItem(dynamic product, [int quantity = 1]) {
    if (product is Map<String, dynamic>) {
      final productId = product['id'].toString();
      if (_cart.containsKey(productId)) {
        final currentQty = _cart[productId]!['quantity'];
        final safeCurrentQty = (currentQty is num) ? currentQty.toInt() : int.tryParse(currentQty.toString()) ?? 0;
        _cart[productId]!['quantity'] = safeCurrentQty + quantity;
      } else {
        _cart[productId] = {
          'quantity': quantity,
          'name': product['name'],
          'price': product['price'],
          'image': product['image_url'] ?? product['image'],
          'image_url': product['image_url'],
          'distributor_id': product['distributor_id'],
          'stock': product['stock'] ?? 1,
        };
      }
    } else if (product is String) {
      addToCart(product, quantity);
    }
    saveCart(); // Auto-save after modification
  }

  void addToCart(String productId, int quantity, {String? name, double? price, String? image, String? imageUrl, int? distributorId}) {
    if (_cart.containsKey(productId)) {
      final currentQty = _cart[productId]!['quantity'];
      final safeCurrentQty = (currentQty is num) ? currentQty.toInt() : int.tryParse(currentQty.toString()) ?? 0;
      _cart[productId]!['quantity'] = safeCurrentQty + quantity;
    } else {
      _cart[productId] = {
        'quantity': quantity,
        'name': name,
        'price': price,
        'image': imageUrl ?? image,
        'image_url': imageUrl,
        'distributor_id': distributorId,
        'stock': 1,
      };
    }
    saveCart(); // Auto-save after modification
  }

  void removeFromCart(String productId) {
    _cart.remove(productId);
    saveCart(); // Auto-save after modification
  }

  void updateQuantity(String productId, int quantity) {
    if (_cart.containsKey(productId)) {
      _cart[productId]!['quantity'] = quantity;
      if (quantity <= 0) {
        _cart.remove(productId);
      }
    }
    saveCart(); // Auto-save after modification
  }

  void clearCart() {
    _cart.clear();
    saveCart(); // Auto-save after modification
  }

  Map<int, List<Map<String, dynamic>>> getItemsByDistributor() {
    return distributorItems;
  }

  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString('shopping_cart');
      if (cartData != null) {
        final decoded = json.decode(cartData);
        _cart.clear();
        
        // Handle different cart data formats
        if (decoded is Map<String, dynamic>) {
          // New format: Map<String, Map<String, dynamic>>
          decoded.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              _cart[key] = Map<String, dynamic>.from(value);
            }
          });
        } else if (decoded is List<dynamic>) {
          // Old format: List<Map<String, dynamic>> - convert to new format
          print('Converting old cart format to new format');
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              final productId = item['id']?.toString();
              if (productId != null) {
                _cart[productId] = {
                  'quantity': item['quantity'] ?? 1,
                  'name': item['name'],
                  'price': item['price'],
                  'image': item['image_url'] ?? item['image'],
                  'image_url': item['image_url'],
                  'distributor_id': item['distributor_id'],
                  'stock': item['stock'] ?? 1,
                };
              }
            }
          }
          // Save in new format
          saveCart();
        }
      }
    } catch (e) {
      print('Error loading cart: $e');
      // Clear corrupted cart data
      _cart.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('shopping_cart');
    }
  }

  Future<void> saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = json.encode(_cart);
      await prefs.setString('shopping_cart', cartData);
    } catch (e) {
      print('Error saving cart: $e');
    }
  }

  Map<String, dynamic> getCart() {
    return Map<String, dynamic>.from(_cart);
  }

  int get itemCount => _cart.length;

  double get totalAmount {
    try {
      return _cart.values.fold(0.0, (sum, item) {
        try {
          // Safe price conversion
          final priceValue = item['price'];
          double price = 0.0;
          if (priceValue is num) {
            price = priceValue.toDouble();
          } else {
            final priceString = priceValue.toString();
            price = double.tryParse(priceString) ?? 0.0;
          }
          
          // Safe quantity conversion  
          final quantityValue = item['quantity'];
          int quantity = 1;
          if (quantityValue is num) {
            quantity = quantityValue.toInt();
          } else {
            final quantityString = quantityValue.toString();
            quantity = int.tryParse(quantityString) ?? 1;
          }
          
          final itemTotal = price * quantity;
          return sum + itemTotal;
        } catch (e) {
          return sum; // Skip problematic items
        }
      });
    } catch (e) {
      return 0.0;
    }
  }

  List<Map<String, dynamic>> get cartItems {
    try {
      if (_cart.isEmpty) return [];
      return _cart.entries.map<Map<String, dynamic>>((e) {
        return <String, dynamic>{
          'id': e.key,
          ...e.value,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Debug method to completely reset cart
  Future<void> resetCart() async {
    try {
      _cart.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('shopping_cart');
      print('Cart completely reset');
    } catch (e) {
      print('Error resetting cart: $e');
    }
  }

  // Debug method to check cart status
  void debugCart() {
    print('=== CART DEBUG ===');
    print('Cart isEmpty: $isEmpty');
    print('Cart itemCount: $itemCount');
    print('Cart totalAmount: $totalAmount');
    print('Cart items: ${_cart.keys.toList()}');
    print('Distributor items: ${distributorItems.keys.toList()}');
    print('==================');
  }
}
