import 'dart:io';
import 'package:flutter/material.dart';
import 'package:apsl_sun_calc/apsl_sun_calc.dart'; // Import the sun calculation library
import 'package:image/image.dart' as img;
import 'package:sun_direction/TakePictureScreen.dart';

class SunDetectionScreen extends StatelessWidget {
  final String imagePath;
  final double latitude;
  final double longitude;
  final DateTime dateTime;

  const SunDetectionScreen(this.imagePath, {super.key, required this.latitude, required this.longitude, required this.dateTime});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sun Detection')),
      body: FutureBuilder<bool>(
        future: detectSunInImage(imagePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.data!) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Center(
                  child: Text('Error: No sun detected. Please take a picture with the sun visible.'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Implement re-take picture functionality
                     Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TakePictureScreen()),
            );
                  },
                  child: const Text('Retake Picture'),
                ),
              ],
            );
          } else {
            // Calculate sun position using the apsl_sun_calc library
            final sunCalc = SunCalc.getPosition(dateTime, latitude, longitude);
            final sunDirection = sunCalc['azimuth']; // Access azimuth from the Map
            final String directionLabel = getCardinalDirection(sunDirection! * (180 / 3.14159)); // Convert radians to degrees
            
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sun detected!'),
                  const SizedBox(height: 16),
                  Text('Direction: ${directionLabel} (${sunDirection.toStringAsFixed(2)}°)', ),
                  const SizedBox(height: 16),
                  // Optionally add a compass or arrow graphic to represent the direction
                  Image.asset('assets/compass.png', width: 200), // Add your compass image here
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Future<bool> detectSunInImage(String imagePath) async {
    final image = img.decodeImage(File(imagePath).readAsBytesSync());
    final pixels = image!.getBytes(); // Gets pixel data as a list of bytes

    int sunPixelCount = 0;
    for (int i = 0; i < pixels.length; i += 4) {
      final red = pixels[i + 1];     // Red channel
      final green = pixels[i + 2];   // Green channel
      final blue = pixels[i + 3];    // Blue channel

      // Improved detection of bright colors (tuning may still be needed):
      if (red > 200 && green > 200 && blue < 100) {
        sunPixelCount++;
      }
    }

    // Threshold for detecting "sun-like" pixels:
    return sunPixelCount > 100;
  }

  String getCardinalDirection(double angle) {
    if (angle >= 337.5 || angle < 22.5) return "N";
    if (angle >= 22.5 && angle < 67.5) return "NE";
    if (angle >= 67.5 && angle < 112.5) return "E";
    if (angle >= 112.5 && angle < 157.5) return "SE";
    if (angle >= 157.5 && angle < 202.5) return "S";
    if (angle >= 202.5 && angle < 247.5) return "SW";
    if (angle >= 247.5 && angle < 292.5) return "W";
    if (angle >= 292.5 && angle < 337.5) return "NW";
    return "N"; // Default fallback
  }
}
