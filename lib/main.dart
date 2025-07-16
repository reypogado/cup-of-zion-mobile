import 'package:cup_of_zion/screens/menu/menu_screen.dart';
import 'package:cup_of_zion/screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true, // still modern, but fully customized
        fontFamily: 'Roboto',

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B3B34), // base color
          primary: const Color(0xFF1B3B34),
          secondary: const Color(0xFFC6B89E),
          background: const Color(0xFFF6F3EF),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onBackground: Colors.black87,
          onSurface: Colors.black87,
          brightness: Brightness.light,
        ),

        scaffoldBackgroundColor: const Color(0xFFF6F3EF),

        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B3B34),
          foregroundColor: Colors.white,
          elevation: 0,
        ),

        // ✅ ElevatedButton (main CTA buttons)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B3B34),
            foregroundColor: Colors.white, // ✅ FIX PURPLE TEXT
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // ✅ TextButton (e.g. flat buttons)
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1B3B34),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        // ✅ OutlinedButton (secondary buttons)
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1B3B34),
            side: const BorderSide(color: Color(0xFF1B3B34)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Text styling
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.black,
          ),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
          labelLarge: TextStyle(fontSize: 14, color: Color(0xFF1B3B34)),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
