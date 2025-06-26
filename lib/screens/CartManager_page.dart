class CartManager {
  static final CartManager _instance = CartManager._internal();
  factory CartManager() => _instance;
  CartManager._internal();

  final List<Map<String, dynamic>> _cart = [];

  List<Map<String, dynamic>> get cartItems => List.unmodifiable(_cart);

  void addItem(Map<String, dynamic> item) {
    _cart.add(item);
  }

  void clearCart() {
    _cart.clear();
  }

  bool get isEmpty => _cart.isEmpty;
}
