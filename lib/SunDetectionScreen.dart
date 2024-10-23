import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_compass_v2/flutter_compass_v2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // Import the geocoding package
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:sunrise_sunset_calc/sunrise_sunset_calc.dart';
import 'dart:math';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_compass_v2/flutter_compass_v2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // Import the geocoding package
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:sunrise_sunset_calc/sunrise_sunset_calc.dart';
import 'dart:math';

class SunDirectionApp extends StatefulWidget {
  const SunDirectionApp({super.key});

  @override
  _SunDirectionAppState createState() => _SunDirectionAppState();
}

class _SunDirectionAppState extends State<SunDirectionApp>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  double? _deviceHeading;
  Position? _userLocation;
  String? _locationName;
  double? _sunAzimuth;
  double? _sunAltitude;
  bool _isNight = false;
  bool _photoCaptured = false;
  late AnimationController _animationController;
  double _previousHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _getLocation();
    _initCompass();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // Adjust the speed
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _cameraController =
        CameraController(cameras.first, ResolutionPreset.medium);
    await _cameraController?.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    _userLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    _getCityName(_userLocation!.latitude, _userLocation!.longitude);
    await _checkDayOrNight();
  }

  Future<void> _getCityName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        setState(() {
          _locationName = placemarks.first.locality ?? '';
        });
      }
    } catch (e) {
      print("Error fetching location name: $e");
    }
  }

  void _initCompass() {
    FlutterCompass.events?.listen((event) {
      double newHeading = event.heading ?? 0.0;
      double difference = (newHeading - _previousHeading).abs();

      // Check if the movement is significant enough before updating the heading
      if (difference > 1.0) {
        setState(() {
          _deviceHeading = newHeading;
          _previousHeading = newHeading;
        });
      }

      _checkSunAlignment();
    });
  }

  Future<void> _checkDayOrNight() async {
    if (_userLocation != null) {
      final now = DateTime.now().toUtc();
      final latitude = _userLocation!.latitude;
      final longitude = _userLocation!.longitude;

      final result = getSunriseSunset(
        latitude,
        longitude,
        const Duration(hours: 0),
        now,
      );

      final sunriseTime = result.sunrise.toUtc();
      final sunsetTime = result.sunset.toUtc();

      setState(() {
        _isNight = now.isBefore(sunriseTime) || now.isAfter(sunsetTime);
      });

      if (!_isNight) {
        _calculateSunPosition();
      }
    }
  }

  void _calculateSunPosition() {
    if (_userLocation != null) {
      final now = DateTime.now().toUtc();
      final latitude = _userLocation!.latitude;
      final longitude = _userLocation!.longitude;

      final dayOfYear = _getDayOfYear(now);
      final declination =
          23.45 * sin((360 / 365) * (dayOfYear - 81) * (pi / 180));
      final timeCorrection =
          4 * (longitude) + 60 * now.timeZoneOffset.inMinutes;
      final solarNoon = 12 - (timeCorrection / 60);

      final hour = now.hour + now.minute / 60 + (now.timeZoneOffset.inHours);
      final hourAngle = 15 * (hour - solarNoon);

      _sunAltitude = asin(
          sin(latitude * (pi / 180)) * sin(declination * (pi / 180)) +
              cos(latitude * (pi / 180)) *
                  cos(declination * (pi / 180)) *
                  cos(hourAngle * (pi / 180)));

      _sunAzimuth = atan2(
            sin(hourAngle * (pi / 180)),
            cos(hourAngle * (pi / 180)) * sin(latitude * (pi / 180)) -
                tan(declination * (pi / 180)) * cos(latitude * (pi / 180)),
          ) *
          (180 / pi);

      setState(() {});
    }
  }

  int _getDayOfYear(DateTime date) {
    return int.parse(DateFormat("D").format(date));
  }

  void _checkSunAlignment() {
    if (_sunAzimuth != null && _deviceHeading != null && !_photoCaptured) {
      const double alignmentThreshold = 10.0; // Define an acceptable range

      // Check if the sun's azimuth is within the threshold of the device's heading
      if ((_sunAzimuth! - _deviceHeading!).abs() <= alignmentThreshold) {
        _capturePhoto();
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        // Take the picture regardless of sun visibility
        final image = await _cameraController!.takePicture();
        _photoCaptured = true; // Prevent multiple captures

        // Navigate to the next screen with the captured image and sun info
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => PictureScreen(
              imagePath: image.path,
              sunAzimuth: _sunAzimuth ?? 0.0, // Use 0.0 if sun azimuth is null
              sunAltitude:
                  _sunAltitude ?? 0.0, // Use 0.0 if sun altitude is null
              location: _locationName ?? 'Unknown',
            ),
          ));
        }
      } catch (e) {
        print("Error capturing photo: $e");
      }
    }
  }

  // Future<void> _capturePhoto() async {
  //   if (_cameraController != null && _cameraController!.value.isInitialized) {
  //     try {
  //       final image = await _cameraController!.takePicture();
  //       _photoCaptured = true; // Prevent multiple captures

  //       // Navigate to the next screen with the captured image and sun info
  //       if (mounted) {
  //         Navigator.of(context).push(MaterialPageRoute(
  //           builder: (context) => PictureScreen(
  //             imagePath: image.path,
  //             sunAzimuth: _sunAzimuth!,
  //             sunAltitude: _sunAltitude!,
  //             location: _locationName ?? 'Unknown',
  //           ),
  //         ));
  //       }
  //     } catch (e) {
  //       print("Error capturing photo: $e");
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.amber,
            title: const Center(child: Text('Sun Direction Guide'))),
        body: Stack(
          children: [
            SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CameraPreview(_cameraController!)),
            if (_isNight) _buildNightMessage(),
            if (!_isNight && _sunAzimuth != null && _deviceHeading != null)
              _buildSunDirectionIndicator(),
            if (!_isNight && _sunAzimuth != null && _sunAltitude != null)
              _buildSunInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildSunDirectionIndicator() {
    double relativeSunDirection = (_sunAzimuth! - _deviceHeading!) % 360;

    return Positioned(
      top: MediaQuery.of(context).size.height / 2,
      left: MediaQuery.of(context).size.width / 2,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: relativeSunDirection * pi / 180,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wb_sunny, color: Colors.yellow, size: 70),
                Container(
                  width: 10,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.yellow,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                CustomPaint(
                  size: const Size(40, 40),
                  painter: ArrowHeadPainter(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSunInfo() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Text(
          'Sun Azimuth: ${_sunAzimuth?.toStringAsFixed(2)}°, '
          'Altitude: ${_sunAltitude?.toStringAsFixed(2)}°',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.0,
          ),
        ),
      ),
    );
  }

  Widget _buildNightMessage() {
    return const Center(
      child: Text(
        'It\'s night time. Please try during the day.',
        style: TextStyle(color: Colors.white, fontSize: 24.0),
      ),
    );
  }
}

class PictureScreen extends StatelessWidget {
  final String imagePath;
  final double sunAzimuth;
  final double sunAltitude;
  final String location;

  const PictureScreen({
    required this.imagePath,
    required this.sunAzimuth,
    required this.sunAltitude,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sun Picture')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Image.file(File(imagePath)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Location: $location\n'
              'Sun Azimuth: ${sunAzimuth.toStringAsFixed(2)}°\n'
              'Sun Altitude: ${sunAltitude.toStringAsFixed(2)}°',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class ArrowHeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    Path path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}


// class SunDirectionApp extends StatefulWidget {
//   const SunDirectionApp({super.key});

//   @override
//   _SunDirectionAppState createState() => _SunDirectionAppState();
// }



// class _SunDirectionAppState extends State<SunDirectionApp> {
//   CameraController? _cameraController;
//   double? _deviceHeading;
//   Position? _userLocation;
//   String? _locationName;
//   double? _sunAzimuth;
//   double? _sunAltitude;
//   bool _isNight = false;
//   bool _photoCaptured = false; // To prevent multiple photos in one session

//   @override
//   void initState() {
//     super.initState();
//     _initCamera();
//     _getLocation();
//     _initCompass();
//   }

//   @override
//   void dispose() {
//     _cameraController?.dispose();
//     super.dispose();
//   }

//   Future<void> _initCamera() async {
//     final cameras = await availableCameras();
//     _cameraController =
//         CameraController(cameras.first, ResolutionPreset.medium);
//     await _cameraController?.initialize();
//     if (mounted) setState(() {});
//   }

//   Future<void> _getLocation() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       return Future.error('Location services are disabled.');
//     }

//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         return Future.error('Location permissions are denied');
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       return Future.error(
//           'Location permissions are permanently denied, we cannot request permissions.');
//     }

//     _userLocation = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high);

//     _getCityName(_userLocation!.latitude, _userLocation!.longitude);
//     await _checkDayOrNight();
//   }

//   Future<void> _getCityName(double latitude, double longitude) async {
//     try {
//       List<Placemark> placemarks =
//           await placemarkFromCoordinates(latitude, longitude);
//       if (placemarks.isNotEmpty) {
//         setState(() {
//           _locationName = placemarks.first.locality ?? '';
//         });
//       }
//     } catch (e) {
//       print("Error fetching location name: $e");
//     }
//   }

//   void _initCompass() {
//     FlutterCompass.events?.listen((event) {
//       setState(() {
//         _deviceHeading = event.heading;
//         _checkSunAlignment();
//       });
//     });
//   }

//   Future<void> _checkDayOrNight() async {
//     if (_userLocation != null) {
//       final now = DateTime.now().toUtc();
//       final latitude = _userLocation!.latitude;
//       final longitude = _userLocation!.longitude;

//       final result = getSunriseSunset(
//         latitude,
//         longitude,
//         const Duration(hours: 0),
//         now,
//       );

//       final sunriseTime = result.sunrise.toUtc();
//       final sunsetTime = result.sunset.toUtc();

//       setState(() {
//         _isNight = now.isBefore(sunriseTime) || now.isAfter(sunsetTime);
//       });

//       if (!_isNight) {
//         _calculateSunPosition();
//       }
//     }
//   }

//   void _calculateSunPosition() {
//     if (_userLocation != null) {
//       final now = DateTime.now().toUtc();
//       final latitude = _userLocation!.latitude;
//       final longitude = _userLocation!.longitude;

//       final dayOfYear = _getDayOfYear(now);
//       final declination =
//           23.45 * sin((360 / 365) * (dayOfYear - 81) * (pi / 180));
//       final timeCorrection =
//           4 * (longitude) + 60 * now.timeZoneOffset.inMinutes;
//       final solarNoon = 12 - (timeCorrection / 60);

//       final hour = now.hour + now.minute / 60 + (now.timeZoneOffset.inHours);
//       final hourAngle = 15 * (hour - solarNoon);

//       _sunAltitude = asin(
//           sin(latitude * (pi / 180)) * sin(declination * (pi / 180)) +
//               cos(latitude * (pi / 180)) *
//                   cos(declination * (pi / 180)) *
//                   cos(hourAngle * (pi / 180)));

//       _sunAzimuth = atan2(
//             sin(hourAngle * (pi / 180)),
//             cos(hourAngle * (pi / 180)) * sin(latitude * (pi / 180)) -
//                 tan(declination * (pi / 180)) * cos(latitude * (pi / 180)),
//           ) *
//           (180 / pi);

//       setState(() {});
//     }
//   }

//   int _getDayOfYear(DateTime date) {
//     return int.parse(DateFormat("D").format(date));
//   }

//   void _checkSunAlignment() {
//     if (_sunAzimuth != null && _deviceHeading != null && !_photoCaptured) {
//       const double alignmentThreshold = 10.0; // Define an acceptable range

//       // Check if the sun's azimuth is within the threshold of the device's heading
//       if ((_sunAzimuth! - _deviceHeading!).abs() <= alignmentThreshold) {
//         _capturePhoto();
//       }
//     }
//   }

//   Future<void> _capturePhoto() async {
//     if (_cameraController != null && _cameraController!.value.isInitialized) {
//       try {
//         final image = await _cameraController!.takePicture();
//         _photoCaptured = true; // Prevent multiple captures

//         // Navigate to the next screen with the captured image and sun info
//         if (mounted) {
//           Navigator.of(context).push(MaterialPageRoute(
//             builder: (context) => PictureScreen(
//               imagePath: image.path,
//               sunAzimuth: _sunAzimuth!,
//               sunAltitude: _sunAltitude!,
//               location: _locationName ?? 'Unknown',
//             ),
//           ));
//         }
//       } catch (e) {
//         print("Error capturing photo: $e");
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_cameraController == null || !_cameraController!.value.isInitialized) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: Scaffold(
//         appBar: AppBar(
//             backgroundColor: Colors.amber,
//             title: const Center(child: Text('Sun Direction Guide'))),
//         body: Stack(
//           children: [
//             SizedBox(
//                 width: double.infinity,
//                 height: double.infinity,
//                 child: CameraPreview(_cameraController!)),
//             if (_isNight) _buildNightMessage(),
//             if (!_isNight && _sunAzimuth != null && _deviceHeading != null)
//               _buildSunDirectionIndicator(),
//             if (!_isNight && _sunAzimuth != null && _sunAltitude != null)
//               _buildSunInfo(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSunDirectionIndicator() {
//     double relativeSunDirection = (_sunAzimuth! - _deviceHeading!) % 360;

//     return Positioned(
//       top: MediaQuery.of(context).size.height / 2,
//       left: MediaQuery.of(context).size.width / 2,
//       child: Transform.rotate(
//         angle: relativeSunDirection * pi / 180,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.wb_sunny, color: Colors.yellow, size: 70),
//             Container(
//               width: 10,
//               height: 100,
//               decoration: BoxDecoration(
//                 color: Colors.yellow,
//                 borderRadius: BorderRadius.circular(5),
//               ),
//             ),
//             CustomPaint(
//               size: const Size(40, 40),
//               painter: ArrowHeadPainter(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSunInfo() {
//     return Positioned(
//       top: 20,
//       left: 20,
//       right: 20,
//       child: Container(
//         decoration: const BoxDecoration(
//           color: Colors.black54,
//           borderRadius: BorderRadius.all(Radius.circular(8.0)),
//         ),
//         padding: const EdgeInsets.all(12.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Sun Azimuth: ${_sunAzimuth?.toStringAsFixed(2)}°',
//               style: const TextStyle(color: Colors.white),
//             ),
//             Text(
//               'Sun Altitude: ${_sunAltitude?.toStringAsFixed(2)}°',
//               style: const TextStyle(color: Colors.white),
//             ),
//             Text(
//               'Location: $_locationName',
//               style: const TextStyle(color: Colors.white),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildNightMessage() {
//     return const Center(
//       child: Text(
//         'It\'s currently night time. Please try again during the day.',
//         style: TextStyle(color: Colors.white, fontSize: 20),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }
// }




// class ArrowHeadPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.yellow
//       ..style = PaintingStyle.fill;

//     final path = Path();
//     path.moveTo(size.width / 2, 0);
//     path.lineTo(0, size.height);
//     path.lineTo(size.width, size.height);
//     path.close();

//     canvas.drawPath(path, paint);
//   }

//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) {
//     return false;
//   }
// }

// class PictureScreen extends StatelessWidget {
//   final String imagePath;
//   final double sunAzimuth;
//   final double sunAltitude;
//   final String location;

//   const PictureScreen({
//     super.key,
//     required this.imagePath,
//     required this.sunAzimuth,
//     required this.sunAltitude,
//     required this.location,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Captured Photo & Sun Info'),
//       ),
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Expanded(child: Image.file(File(imagePath))),
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('Sun Azimuth: ${sunAzimuth.toStringAsFixed(2)}°'),
//                 Text('Sun Altitude: ${sunAltitude.toStringAsFixed(2)}°'),
//                 Text('Location: $location'),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
