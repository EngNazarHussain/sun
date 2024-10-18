import 'package:flutter/material.dart';
import 'TakePictureScreen.dart'; // Ensure the path is correct

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sun Direction',
            debugShowCheckedModeBanner: false, // Hides the debug banner


      home: HomeScreen(), // Using a separate HomeScreen widget
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TakePictureScreen()),
            );
          },
          child: Container(
            decoration: const BoxDecoration(color: Colors.amber),
            padding: const EdgeInsets.all(15),
            child: const Text(
              'Take a Picture',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }
}
