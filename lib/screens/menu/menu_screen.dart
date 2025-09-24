import 'package:flutter/material.dart';
import 'package:cup_of_zion/data/coffee_data.dart';
import 'package:cup_of_zion/screens/menu/coffee_detail_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 7, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cup of Zion'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Coffee'),
            Tab(text: 'Non-Coffee'),
            Tab(text: 'Fruities'),
            Tab(text: 'Milkshake'),
            Tab(text: 'Matcha Series'),
            Tab(text: 'Fresh Fruit'),
            Tab(text: 'Others'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildGrid('coffee'),
          buildGrid('non-coffee'),
          buildGrid('fruit'),
          buildGrid('milkshake'),
          buildGrid('matcha-series'),
          buildGrid('fresh-fruit'),
          buildGrid('others'),
        ],
      ),
    );
  }
}

Widget buildGrid(String type) {
  final filtered = drinks.where((e) => e['base'] == type).toList();

  return LayoutBuilder(
    builder: (context, constraints) {
      double maxItemWidth = 180;
      double screenWidth = constraints.maxWidth;
      double itemFontSize = screenWidth < 400 ? 12 : 13;

      return GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filtered.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxItemWidth,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 3 / 4.3,
        ),
        itemBuilder: (context, index) {
          final drink = filtered[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CoffeeDetailScreen(coffee: drink),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Hero(
                      tag: drink['name'],
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.asset(
                          drink['image'],
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            drink['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: itemFontSize,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Icon(Icons.star, color: Colors.amber, size: 14),
                              SizedBox(width: 4),
                              Text('4.5', style: TextStyle(fontSize: 11)),
                              Spacer(),
                              Icon(Icons.favorite_border, size: 14),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            "Php ${drink['price']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
