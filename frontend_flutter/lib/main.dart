import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const EcoSmartApp());
}

class EcoSmartApp extends StatelessWidget {
  const EcoSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eco-Smart',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B8A6F)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
