import 'dart:async';

import 'package:cup_of_zion/screens/transaction_records/transaction_records_screen.dart';
import 'package:cup_of_zion/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'menu/menu_screen.dart';
import 'cart/cart_screen.dart';
import 'settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MenuScreen(),
    const CartScreen(),
    const TransactionRecordsScreen(),
    const SettingsScreen(),
  ];

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();

    // ✅ Start periodic sync every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      SyncService.syncTransactions();
    });
  }

  @override
  void dispose() {
    // ❌ Cancel timer to prevent memory leaks
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF1B3B34),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_cafe_outlined),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.my_library_books_rounded),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
