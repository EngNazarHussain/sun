import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Add permission_handler package
import 'package:sun_direction/SunDetectionScreen.dart';

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key});

  @override
  _TakePictureScreenState createState() => _TakePictureScreenState();
}

class _TakePictureScreenState extends State<TakePictureScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture; // Make it nullable for better control
  List<CameraDescription>? cameras; // To store available cameras

  @override
  void initState() {
    super.initState();
    initializeCamera(); // Call a method to handle camera initialization
  }

  Future<void> initializeCamera() async {
    try {
      // Request camera permissions
      await _requestCameraPermission();

      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        _controller = CameraController(
          cameras!.first, // Use the first available camera
          ResolutionPreset.medium,
        );
        _initializeControllerFuture = _controller!.initialize();
        setState(() {}); // Rebuild to reflect camera initialization state
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (result != PermissionStatus.granted) {
        // Handle permission denial
        print('Camera permission denied');
        // Optionally, you could show a message to the user
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a Picture')),
      body: _initializeControllerFuture == null
          ? const Center(child: Text('Initializing camera...'))
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller!);
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error initializing camera'));
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
      floatingActionButton: _initializeControllerFuture == null
          ? null
          : FloatingActionButton(
              child: const Icon(Icons.camera),
              onPressed: () async {
                try {
                  await _initializeControllerFuture;
                  final image = await _controller!.takePicture();
                  // Navigate to the SunDetectionScreen with the image path
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SunDetectionScreen(
                        image.path,
                        latitude: 0.0, // Provide your latitude
                        longitude: 0.0, // Provide your longitude
                        dateTime: DateTime.now(), // Provide current date/time
                      ),
                    ),
                  );
                } catch (e) {
                  print(e);
                }
              },
            ),
    );
  }
}
