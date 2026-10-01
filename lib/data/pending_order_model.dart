import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_on_model.dart';

/// Kitchen preparation workflow for a pending order.
/// Mirrors `OrderStatus` in coz-web-page/src/context/OrdersContext.tsx.
enum OrderStatus {
  pending('pending', 'Pending'),
  making('making', 'Crafting'),
  serving('serving', 'Now Serving');

  const OrderStatus(this.id, this.label);

  final String id;
  final String label;

  static OrderStatus fromId(String? id) {
    return OrderStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => OrderStatus.pending,
    );
  }
}

/// One line of a pending order, as stored by the web app.
class PendingOrderItem {
  final String name;
  final String assetPath;
  final double unitPrice;
  final String temperature;
  final String milk;
  final String size;
  final String shotType;
  final int extraShots;
  final int quantity;
  final List<AddOn> addOns;

  PendingOrderItem({
    required this.name,
    required this.assetPath,
    required this.unitPrice,
    required this.temperature,
    required this.milk,
    required this.size,
    required this.shotType,
    required this.extraShots,
    required this.quantity,
    required this.addOns,
  });

  factory PendingOrderItem.fromMap(Map<String, dynamic> map) {
    return PendingOrderItem(
      name: (map['name'] ?? 'Drink').toString(),
      assetPath: (map['assetPath'] ?? '').toString(),
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      temperature: (map['temperature'] ?? '').toString(),
      milk: (map['milk'] ?? '').toString(),
      size: (map['size'] ?? '').toString(),
      shotType: (map['shotType'] ?? '').toString(),
      extraShots: (map['extraShots'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      addOns: ((map['addOns'] as List?) ?? [])
          .map((e) => AddOn(
                name: (e['name'] ?? '').toString(),
                price: (e['price'] as num?)?.toDouble() ?? 0,
              ))
          .toList(),
    );
  }

  double get lineTotal => unitPrice * quantity;

  /// "2x premium shot" — the note the transaction/receipt carries.
  String get shotNote =>
      shotType.isNotEmpty && extraShots > 0 ? '${extraShots}x $shotType shot' : '';

  /// Human-readable option summary shown under the item name.
  String get description {
    final parts = <String>[
      if (temperature.isNotEmpty && temperature != 'none') temperature,
      if (milk.isNotEmpty && milk != 'none') '$milk milk',
      if (size.isNotEmpty) size,
      if (shotNote.isNotEmpty) shotNote,
      ...addOns.map((a) => a.name),
    ];
    return parts.join(' · ');
  }

  /// Shaped like `CartItem.toJson()` so it lands in the transactions table
  /// exactly as an in-app order would.
  Map<String, dynamic> toTransactionJson() => {
        'name': name,
        'image': assetPath,
        'price': unitPrice,
        'temperature': temperature.isEmpty ? 'none' : temperature,
        'milk': milk.isEmpty ? 'none' : milk,
        'size': size.isEmpty ? 'regular' : size,
        'quantity': quantity,
        'drinkOptions': shotNote,
        'addOns': addOns.map((a) => a.toJson()).toList(),
      };
}

/// An order placed from the web app, waiting to be prepared.
class PendingOrder {
  final String id; // Firestore document id
  final String reference;
  final String customerName;
  final String phone;
  final List<PendingOrderItem> items;
  final double total;
  final OrderStatus status;
  final DateTime createdAt;

  PendingOrder({
    required this.id,
    required this.reference,
    required this.customerName,
    required this.phone,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  factory PendingOrder.fromDoc(String id, Map<String, dynamic> data) {
    return PendingOrder(
      id: id,
      reference: (data['reference'] ?? '').toString(),
      customerName: (data['customer_name'] ?? '').toString(),
      phone: (data['customer_phone'] ?? '').toString(),
      total: (data['total_price'] as num?)?.toDouble() ?? 0,
      status: OrderStatus.fromId(data['status'] as String?),
      createdAt: _parseDate(data['created_at']),
      items: ((data['items'] as List?) ?? [])
          .map((e) => PendingOrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  String get displayName => customerName.isEmpty ? 'Walk-in' : customerName;
}
