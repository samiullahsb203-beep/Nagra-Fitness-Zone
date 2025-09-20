
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gym Management',
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: Center(
          child: Text('Gym Management App Working!',
              style: TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}
