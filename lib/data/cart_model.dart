import 'package:cup_of_zion/data/add_on_model.dart';


class CartItem {
  final String name;
  final String image;
  final double price;
  final String temperature;
  final String milk;
  final String size;
  final String drinkOptions;
  final List<AddOn> addOns;
  int quantity;

  CartItem({
    required this.name,
    required this.image,
    required this.price,
    required this.temperature,
    required this.milk,
    required this.size,
    required this.drinkOptions,
    required this.addOns,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'image': image,
        'price': price,
        'temperature': temperature,
        'milk': milk,
        'size': size,
        'quantity': quantity,
        'drinkOptions': drinkOptions,
        'addOns': addOns.map((e) => e.toJson()).toList(),
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      name: json['name'],
      image: json['image'],
      price: (json['price'] as num).toDouble(),
      temperature: json['temperature'],
      milk: json['milk'],
      size: json['size'],
      quantity: json['quantity'] ?? 1,
      drinkOptions: json['drinkOptions'],
      addOns: (json['addOns'] as List? ?? [])
          .map((e) => AddOn.fromJson(e))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CartItem &&
        name == other.name &&
        temperature == other.temperature &&
        milk == other.milk &&
        size == other.size &&
        drinkOptions == other.drinkOptions &&
        _listEquals(addOns, other.addOns);
  }

  bool _listEquals(List<AddOn> a, List<AddOn> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name || a[i].price != b[i].price) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
        name,
        temperature,
        milk,
        size,
        drinkOptions,
        ...addOns.map((e) => '${e.name}:${e.price}'),
      ]);
}
