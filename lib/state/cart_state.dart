// lib/state/cart_state.dart
import '../data/cart_model.dart';

class CartState {
  static final List<CartItem> _items = [];

  static List<CartItem> get items => _items;

  static void addItem(CartItem item) {
    final index = _items.indexWhere((i) => i.name == item.name);

    if (index != -1) {
      _items[index].quantity += item.quantity;
    } else {
      _items.add(item);
    }
  }

  static void removeItem(CartItem item) {
    _items.remove(item);
  }

  static double get totalPrice =>
      _items.fold(0, (sum, item) => sum + (item.price * item.quantity));

  static void clearCart() {
    _items.clear();
  }
}
