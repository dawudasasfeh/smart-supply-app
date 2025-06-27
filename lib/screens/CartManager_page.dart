class CartManager {
  static final CartManager _instance = CartManager._internal();
  factory CartManager() => _instance;

  CartManager._internal();

  final List<Map<String, dynamic>> _cartItems = [];

  List<Map<String, dynamic>> get cartItems => _cartItems;

  void addItem(Map<String, dynamic> item) {
    _cartItems.add(item);
  }

  void clearCart() {
    _cartItems.clear();
  }
}
