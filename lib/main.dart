import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const CaisseApp());
}

class CaisseApp extends StatelessWidget {
  const CaisseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ma Caisse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}