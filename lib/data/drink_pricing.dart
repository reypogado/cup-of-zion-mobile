/// Single source of truth for a drink's unit price, so the menu card and the
/// detail screen can never disagree.
double drinkUnitPrice(
  Map<String, dynamic> drink, {
  String milk = 'none',
  String size = 'none',
  int extraShots = 0,
  double addOnsPrice = 0,
}) {
  final String base = drink['base'];
  double price = (double.tryParse(drink['price'] ?? '0') ?? 0) + addOnsPrice;

  if (milk == 'oat') price += 30;

  // Fruit teas: Small ₱45 / Medium ₱60 (+15) / Large ₱80 (+35)
  // All other categories: Medium +₱20, Large +₱40
  if (size == 'medium') {
    price += base == 'fruit' ? 15 : 20;
  } else if (size == 'large') {
    price += base == 'fruit' ? 35 : 40;
  }

  // All beans are premium — the premium rates below are the only rates.
  if (base == 'coffee') {
    price += 10;
    price += extraShots * 30;
  } else if (base == 'matcha-series') {
    // Matcha Espresso carries the +₱10 espresso charge; other matcha items do not
    if (drink['name'] == 'Matcha Espresso') price += 10;
    price += extraShots * 30;
  } else {
    price += extraShots * 20;
  }

  return price;
}

/// The price shown on the menu card: what the detail screen opens at, using
/// each option list's first entry (the detail screen's defaults).
double drinkStartingPrice(Map<String, dynamic> drink) {
  final milkOptions = drink['milkOptions'] as List? ?? const [];
  final sizeOptions = drink['sizeOptions'] as List? ?? const [];
  return drinkUnitPrice(
    drink,
    milk: milkOptions.isNotEmpty ? milkOptions.first : 'none',
    size: sizeOptions.isNotEmpty ? sizeOptions.first : 'none',
  );
}
