import 'package:flutter/material.dart';
import 'package:flutter_compass_v2/flutter_compass_v2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // Import the geocoding package
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:sunrise_sunset_calc/sunrise_sunset_calc.dart';
import 'dart:math';

class SunDirectionApp extends StatefulWidget {
  @override
  _SunDirectionAppState createState() => _SunDirectionAppState();
}

class _SunDirectionAppState extends State<SunDirectionApp> {
  CameraController? _cameraController;
  double? _deviceHeading; // Compass heading in degrees
  Position? _userLocation; // User's latitude and longitude
  String? _locationName; // User's location name
  double? _sunAzimuth; // Sun's azimuth angle
  double? _sunAltitude; // Sun's altitude angle
  bool _isNight = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _getLocation();
    _initCompass();
  }

  @override
  void dispose() {
    _cameraController?.dispose();

    super.dispose();
  }

  // Initialize camera
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _cameraController =
        CameraController(cameras.first, ResolutionPreset.medium);
    await _cameraController?.initialize();
    if (mounted) setState(() {});
  }

  // Get user location
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

    // Fetch the city name based on latitude and longitude
    _getCityName(_userLocation!.latitude, _userLocation!.longitude);

    await _checkDayOrNight();
  }

  // Get city name from latitude and longitude
  Future<void> _getCityName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        setState(() {
          _locationName = placemarks.first.locality ?? ''; // Get the city name
          print('Location ' + _locationName.toString());
        });
      }
    } catch (e) {
      print("Error fetching location name: $e");
    }
  }

  // Initialize compass to get device heading
  void _initCompass() {
    FlutterCompass.events?.listen((event) {
      setState(() {
        _deviceHeading = event.heading;
      });
    });
  }

  // Check if it's day or night based on sunrise and sunset
  Future<void> _checkDayOrNight() async {
    if (_userLocation != null) {
      final now = DateTime.now().toUtc();
      final latitude = _userLocation!.latitude;
      final longitude = _userLocation!.longitude;

      final result = getSunriseSunset(
        latitude,
        longitude,
        Duration(hours: 0),
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

  // Manually calculate sun position based on user's location and current time
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

      // Calculate solar altitude
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

  // Get the day of the year
  int _getDayOfYear(DateTime date) {
    return int.parse(DateFormat("D").format(date));
  }

  // Get sun direction as a string
  String _getSunDirection() {
    if (_sunAzimuth != null) {
      if (_sunAzimuth! >= 337.5 || _sunAzimuth! < 22.5) {
        return 'North';
      } else if (_sunAzimuth! >= 22.5 && _sunAzimuth! < 67.5) {
        return 'Northeast';
      } else if (_sunAzimuth! >= 67.5 && _sunAzimuth! < 112.5) {
        return 'East';
      } else if (_sunAzimuth! >= 112.5 && _sunAzimuth! < 157.5) {
        return 'Southeast';
      } else if (_sunAzimuth! >= 157.5 && _sunAzimuth! < 202.5) {
        return 'South';
      } else if (_sunAzimuth! >= 202.5 && _sunAzimuth! < 247.5) {
        return 'Southwest';
      } else if (_sunAzimuth! >= 247.5 && _sunAzimuth! < 292.5) {
        return 'West';
      } else {
        return 'Northwest';
      }
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.amber,
            title: Center(child: const Text('Sun Direction Guide'))),
        body: Stack(
          children: [
            Container(
                width: double.infinity,
                height: double.infinity,
                child: CameraPreview(_cameraController!)),
            if (_isNight) _buildNightMessage(),
            if (!_isNight && _sunAzimuth != null && _deviceHeading != null)
              _buildSunDirectionIndicator(),
            if (!_isNight && _sunAzimuth != null && _sunAltitude != null)
              _buildSunInfo(), // Show sun information
          ],
        ),
      ),
    );
  }

  // Widget to display sun direction
  Widget _buildSunDirectionIndicator() {
    double relativeSunDirection = (_sunAzimuth! - _deviceHeading!) % 360;

    return Positioned(
      top: MediaQuery.of(context).size.height / 2,
      left: MediaQuery.of(context).size.width / 2,
      child: Transform.rotate(
        angle: relativeSunDirection * pi / 180,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_sunny, color: Colors.yellow, size: 70),
            Container(
              width: 10, // Wider arrow body
              height: 100, // Adjusted height
              decoration: BoxDecoration(
                color: Colors.yellow,
                borderRadius: BorderRadius.circular(5), // Rounded edges
              ),
            ),
            CustomPaint(
              size: Size(40, 40),
              painter: ArrowHeadPainter(),
            ),
          ],
        ),
      ),
    );
  }

  // Widget to show sun information
  Widget _buildSunInfo() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadiusDirectional.all(Radius.circular(15)),
        ),
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Sun Azimuth: ${_sunAzimuth!.toStringAsFixed(2)}°',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text(
              'Sun Altitude: ${(_sunAltitude! * (180 / pi)).toStringAsFixed(2)}°',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text(
              'Direction: ${_getSunDirection()}',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (_locationName != null) // Show the location name
              Text(
                'Location: $_locationName',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }

  // Widget to show a night message
  Widget _buildNightMessage() {
    return Center(
      child: Container(
        color: Colors.black54,
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No Sun, It\'s Night or Sunset',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}

// Custom painter for the arrowhead
class ArrowHeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0) // Top center point
      ..lineTo(0, size.height) // Left bottom point
      ..lineTo(size.width, size.height) // Right bottom point
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
