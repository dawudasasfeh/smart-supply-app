import 'package:flutter/foundation.dart';

class CartManager extends ChangeNotifier {
  static final CartManager _instance = CartManager._internal();
  factory CartManager() => _instance;

  CartManager._internal();

  final List<Map<String, dynamic>> _cartItems = [];

  List<Map<String, dynamic>> get cartItems => _cartItems;

  void addItem(Map<String, dynamic> item) {
    final existingIndex = _cartItems.indexWhere((e) => e['id'] == item['id']);
    if (existingIndex >= 0) {
      final currentQty = _cartItems[existingIndex]['quantity'] as int? ?? 1;
      final stock = _cartItems[existingIndex]['stock'] as int? ?? 1;
      if (currentQty < stock) {
        _cartItems[existingIndex]['quantity'] = currentQty + 1;
        notifyListeners();
      }
    } else {
      _cartItems.add({
        ...item,
        'quantity': 1,
        'stock': item['stock'] ?? 1,
      });
      notifyListeners();
    }
  }

  void updateQuantity(int productId, int newQuantity) {
    final index = _cartItems.indexWhere((item) => item['id'] == productId);
    if (index >= 0) {
      final stock = _cartItems[index]['stock'] as int? ?? 1;
      if (newQuantity <= stock && newQuantity > 0) {
        _cartItems[index]['quantity'] = newQuantity;
        notifyListeners();
      }
    }
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }
}
