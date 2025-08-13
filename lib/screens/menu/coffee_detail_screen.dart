import 'package:cup_of_zion/data/add_on_model.dart';
import 'package:flutter/material.dart';
import '../../data/cart_model.dart';
import '../../state/cart_state.dart';

class CoffeeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> coffee;

  const CoffeeDetailScreen({required this.coffee, super.key});

  @override
  State<CoffeeDetailScreen> createState() => _CoffeeDetailScreenState();
}

class _CoffeeDetailScreenState extends State<CoffeeDetailScreen> {
  int quantity = 1;
  String selectedTemperature = 'none';
  String selectedMilk = 'none';
  String selectedSize = 'regular';
  String selectedDrinkOption = '';
  List<AddOn> selectedAddOns = [];

  @override
  void initState() {
    super.initState();
    final options = widget.coffee['options'] as List;
    if (options.isNotEmpty) selectedTemperature = options.first;

    final base = widget.coffee['base'];
    if (base == 'coffee' || base == 'non-coffee') {
      selectedMilk = 'regular';
    }

    final sizeOptions = widget.coffee['sizeOptions'] as List;
    if (sizeOptions.isNotEmpty) selectedSize = sizeOptions.first;

    final drinkOptionList = widget.coffee['drinkOptions'] as List?;
    if (drinkOptionList != null && drinkOptionList.isNotEmpty) {
      selectedDrinkOption = drinkOptionList.first;
    }
  }

  void increment() => setState(() => quantity++);
  void decrement() {
    if (quantity > 1) setState(() => quantity--);
  }

  @override
  Widget build(BuildContext context) {
    final coffee = widget.coffee;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    final double basePrice = double.tryParse(coffee['price'] ?? '0') ?? 0;
    final double addOnsPrice = selectedAddOns.fold(0, (sum, addon) => sum + addon.price);

    double adjustedPrice = basePrice + addOnsPrice;
    if (selectedMilk == 'oat') adjustedPrice += 20;
    if (selectedSize == 'upsize') adjustedPrice += 30;
    final double totalPrice = quantity * adjustedPrice;

    return Scaffold(
      backgroundColor: const Color(0xFF1B3B34),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B34),
        leading: const BackButton(color: Colors.white),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.favorite_border, color: Colors.white),
          ),
        ],
        elevation: 0,
      ),
      body: isPortrait
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Hero(
                    tag: coffee['name'],
                    child: Image.asset(
                      coffee['image'],
                      height: screenHeight * 0.32,
                      width: screenWidth * 0.8,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Expanded(
                  child: buildDetailsContent(coffee, basePrice, adjustedPrice, totalPrice),
                ),
              ],
            )
          : Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Hero(
                    tag: coffee['name'],
                    child: Image.asset(
                      coffee['image'],
                      height: screenHeight * 0.6,
                      width: screenWidth * 0.4,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Expanded(
                  child: buildDetailsContent(coffee, basePrice, adjustedPrice, totalPrice),
                ),
              ],
            ),
    );
  }

  Widget buildDetailsContent(
    Map<String, dynamic> coffee,
    double basePrice,
    double adjustedPrice,
    double totalPrice,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coffee['name'],
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(coffee['ingredients'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 16),
                  const Text('Description',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(coffee['description'],
                      style: TextStyle(color: Colors.grey[700], height: 1.5)),
                  const SizedBox(height: 16),

                  if ((coffee['options'] as List).isNotEmpty)
                    buildChoiceChips('Temperature:', coffee['options'], selectedTemperature,
                        (val) => setState(() => selectedTemperature = val)),

                  if ((coffee['milkOptions'] as List).isNotEmpty)
                    buildChoiceChips('Milk Option:', coffee['milkOptions'], selectedMilk,
                        (val) => setState(() => selectedMilk = val)),

                  if ((coffee['sizeOptions'] as List).isNotEmpty)
                    buildChoiceChips('Size:', coffee['sizeOptions'], selectedSize,
                        (val) => setState(() => selectedSize = val)),

                  if ((coffee['drinkOptions'] as List?)?.isNotEmpty ?? false)
                    buildChoiceChips('Drink Option:', coffee['drinkOptions'],
                        selectedDrinkOption, (val) => setState(() => selectedDrinkOption = val)),

                  if ((coffee['add_ons'] as List?)?.isNotEmpty ?? false)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add-ons:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: (coffee['add_ons'] as List).map<Widget>((addonMap) {
                            final addon = AddOn(
                              name: addonMap['name'],
                              price: (addonMap['price'] as num).toDouble(),
                            );
                            final isSelected =
                                selectedAddOns.any((a) => a.name == addon.name);
                            return FilterChip(
                              label:
                                  Text('${addon.name} (+${addon.price.toStringAsFixed(0)})'),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  isSelected
                                      ? selectedAddOns.removeWhere(
                                          (a) => a.name == addon.name)
                                      : selectedAddOns.add(addon);
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  Row(
                    children: [
                      const Text('Quantity:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: decrement,
                              icon: const Icon(Icons.remove),
                              splashRadius: 18,
                            ),
                            Text(quantity.toString(),
                                style: const TextStyle(fontSize: 14)),
                            IconButton(
                              onPressed: increment,
                              icon: const Icon(Icons.add),
                              splashRadius: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Php ${totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const Spacer(),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    CartState.addItem(CartItem(
                      name: coffee['name'],
                      image: coffee['image'],
                      price: adjustedPrice,
                      temperature: selectedTemperature,
                      milk: selectedMilk,
                      size: selectedSize,
                      quantity: quantity,
                      drinkOptions: selectedDrinkOption,
                      addOns: selectedAddOns,
                    ));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "${coffee['name']} ($selectedTemperature, $selectedMilk milk, $selectedSize) x$quantity added to cart",
                        ),
                        backgroundColor: Colors.green[800],
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B3B34),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Add to Cart', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildChoiceChips(String label, List options, String selectedValue,
      void Function(String) onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: options.map<Widget>((opt) {
            final value = opt.toString();
            return ChoiceChip(
              label: Text(value[0].toUpperCase() + value.substring(1)),
              selected: selectedValue == value,
              onSelected: (_) => onSelected(value),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
