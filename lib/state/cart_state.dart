import '../data/cart_model.dart';

class CartState {
  static final List<CartItem> _items = [];

  static List<CartItem> get items => List.unmodifiable(_items);

  static double get totalPrice =>
      _items.fold(0, (sum, item) {
        final addOnsTotal = item.addOns.fold(0.0, (s, a) => s + a.price);
        return sum + ((item.price + addOnsTotal) * item.quantity);
      });

  static void addItem(CartItem newItem) {
    final existingIndex = _items.indexWhere((item) => item == newItem);
    if (existingIndex != -1) {
      _items[existingIndex].quantity += newItem.quantity;
    } else {
      _items.add(newItem);
    }
  }

  static void removeItem(CartItem item) {
    _items.remove(item);
  }

  static void clearCart() {
    _items.clear();
  }
}
