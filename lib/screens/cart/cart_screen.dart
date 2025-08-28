import 'package:cup_of_zion/services/bluetooth_service.dart';
import 'package:cup_of_zion/services/local_transaction_service.dart';
import 'package:cup_of_zion/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../state/cart_state.dart';
import '../../data/cart_model.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _printerService = BluetoothPrinterService();
  final _nameController = TextEditingController();
  final _localDb = LocalTransactionService();
  final _syncService = SyncService();
  String _selectedStatus = 'paid';
  String _selectedPayment = 'cash';

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPrintPreference();
  }

  bool _shouldPrintReceipt = true;
  Future<void> _loadPrintPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shouldPrintReceipt = prefs.getBool('print_receipt') ?? true;
    });
  }

  Future<void> _savePrintPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('print_receipt', value);
  }

  void incrementQuantity(CartItem item) {
    setState(() => item.quantity++);
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
    setState(() => CartState.removeItem(item));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${item.name} removed from cart"),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> submitOrder(String? customerName) async {
    setState(() => _isSubmitting = true);

    try {
      // Save locally and get reference number
      final referenceNumber = await _localDb.insertTransaction(
        customerName: customerName,
        items: CartState.items.map((e) => e.toJson()).toList(),
        totalPrice: CartState.totalPrice,
        status: _selectedStatus,
        payment: _selectedPayment,
      );

      // Attempt to print

      if (_shouldPrintReceipt) {
        try {
          await _printerService.printReceipt(
            CartState.items,
            customerName: customerName,
            referenceNumber: referenceNumber,
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Print failed: $e"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 40, 16, 0), // Top padding
            ),
          );
        }
      }

      // Fire-and-forget sync (don't await)
      SyncService.syncTransactions();

      // Always clear cart and reset
      CartState.clearCart();
      _nameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order submitted."),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
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
                        key: Key("${item.name}-$index"),
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Temp: ${item.temperature}, Milk: ${item.milk}, Size: ${item.size}"
                                "${item.drinkOptions.isNotEmpty ? ', ${item.drinkOptions}' : ''}"
                                "${item.addOns.isNotEmpty ? ', Add-ons: ${item.addOns.map((e) => e.name).join(', ')}' : ''}",
                              ),

                              Text(
                                "Php ${(item.price * item.quantity).toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                _nameController.clear();
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    bool printChecked = _shouldPrintReceipt;

                                    return StatefulBuilder(
                                      builder: (context, setState) => AlertDialog(
                                        title: const Text("Confirm Submission"),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const SizedBox(height: 5),

                                              // Customer Name Input
                                              TextField(
                                                controller: _nameController,
                                                decoration: const InputDecoration(
                                                  labelText:
                                                      "Customer name (optional):",
                                                  hintText: "e.g. rey",
                                                  border: OutlineInputBorder(),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                ),
                                              ),

                                              const SizedBox(height: 12),

                                              // Payment Status Dropdown
                                              Row(
                                                children: [
                                                  // Payment Status Dropdown
                                                  Expanded(
                                                    child: DropdownButtonFormField<String>(
                                                      value: _selectedStatus,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Payment Status',
                                                            border:
                                                                OutlineInputBorder(),
                                                          ),
                                                      items: const [
                                                        DropdownMenuItem(
                                                          value: 'paid',
                                                          child: Text('Paid'),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: 'unpaid',
                                                          child: Text('Unpaid'),
                                                        ),
                                                      ],
                                                      onChanged: (value) {
                                                        if (value != null) {
                                                          setState(
                                                            () =>
                                                                _selectedStatus =
                                                                    value,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    width: 12,
                                                  ), // spacing between dropdowns
                                                  // Payment Method Dropdown
                                                  Expanded(
                                                    child: DropdownButtonFormField<String>(
                                                      value: _selectedPayment,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Payment Method',
                                                            border:
                                                                OutlineInputBorder(),
                                                          ),
                                                      items: const [
                                                        DropdownMenuItem(
                                                          value: 'cash',
                                                          child: Text('Cash'),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: 'gcash',
                                                          child: Text('GCash'),
                                                        ),
                                                      ],
                                                      onChanged: (value) {
                                                        if (value != null) {
                                                          setState(
                                                            () =>
                                                                _selectedPayment =
                                                                    value,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              // Print Checkbox
                                              CheckboxListTile(
                                                title: const Text(
                                                  "Print receipt",
                                                ),
                                                value: printChecked,
                                                controlAffinity:
                                                    ListTileControlAffinity
                                                        .leading,
                                                onChanged: (value) {
                                                  if (value != null) {
                                                    setState(
                                                      () =>
                                                          printChecked = value,
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),

                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              _savePrintPreference(
                                                printChecked,
                                              );
                                              setState(() {
                                                _shouldPrintReceipt =
                                                    printChecked;
                                              });
                                              Navigator.pop(context, true);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF1B3B34,
                                              ),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text("Confirm"),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );

                                if (confirm == true) {
                                  final name = _nameController.text.trim();
                                  await submitOrder(name.isEmpty ? null : name);
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
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("Submit Order"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
