import 'package:cup_of_zion/services/bluetooth_service.dart';
import 'package:flutter/material.dart';
import '../../state/cart_state.dart';
import '../../data/cart_model.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _printerService = BluetoothPrinterService(); // instance

  void incrementQuantity(CartItem item) {
    setState(() {
      item.quantity++;
    });
  }

  void decrementQuantity(CartItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        CartState.removeItem(item);
      }
    });
  }

  void removeItem(CartItem item) {
    setState(() {
      CartState.removeItem(item);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${item.name} removed from cart"),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red[700],
      ),
    );
  }

  void submitOrder() async {
    try {
      await _printerService.printReceipt(CartState.items);
      CartState.clearCart();
      setState(() {}); // refresh UI

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order submitted and printed."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Print failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = CartState.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Cart"),
        backgroundColor: const Color(0xFF1B3B34),
      ),
      body: cartItems.isEmpty
          ? const Center(child: Text("Your cart is empty."))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Dismissible(
                        key: Key(item.name),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => removeItem(item),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Image.asset(
                            item.image,
                            width: 50,
                            height: 50,
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            "Php ${(item.price * item.quantity).toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: SizedBox(
                            width: 110,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => decrementQuantity(item),
                                ),
                                Text('${item.quantity}'),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => incrementQuantity(item),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Total: Php ${CartState.totalPrice.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Confirm Submission"),
                              content: const Text(
                                "Are you sure you want to submit this order and print the receipt?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF1B3B34),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text("Confirm"),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            submitOrder();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B3B34),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Submit Order"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
