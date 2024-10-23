import 'package:flutter/material.dart';
import 'package:sun_direction/SunDetectionScreen.dart';
// Ensure the path is correct

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
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
      appBar: AppBar(
          backgroundColor: Colors.amber,
          title: const Center(child: Text('Home'))),
      body: Center(
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SunDirectionApp()),
            );
          },
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadiusDirectional.all(Radius.circular(15))),
            padding: const EdgeInsets.all(15),
            child: const Text(
              'Check Sun Direction',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }
}
