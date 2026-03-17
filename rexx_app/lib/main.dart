import 'package:flutter/material.dart';
import 'pages/home_screen.dart';

void main() {
  runApp(const RexxApp());
}

class RexxApp extends StatelessWidget {
  const RexxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RexxHomeScreen(),
    );
  }
}
