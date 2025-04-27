import 'package:bridge_cheat_detector/utils/ear_calculator.dart' as utils;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../widgets/camera_view.dart';
import '../widgets/result_display.dart';
import '../models/blink_detection.dart';
import '../models/anomaly_detection.dart';
import '../services/yolo_service.dart';
import '../utils/ear_calculator.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isDetecting = false;
  bool _isInitialized = false;
  int _selectedCameraIndex = 0;
  final YoloService _yoloService = YoloService();
  final utils.EARCalculator _earCalculator = utils.EARCalculator();
  final BlinkDetection _blinkDetection = BlinkDetection();
  final AnomalyDetection _anomalyDetection = AnomalyDetection();
  List<Map<String, dynamic>> _blinkEvents = [];
  bool _isModelLoaded = false;

  Timer? _processingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await _yoloService.loadModel();
      setState(() {
        _isModelLoaded = true;
      });
    } catch (e) {
      debugPrint('Failed to load model: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load detection model: $e')),
        );
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![_selectedCameraIndex],
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );

        await _cameraController!.initialize();

        setState(() {
          _isInitialized = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras found')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera initialization error: $e')),
        );
      }
    }
  }

  void _toggleDetection() {
    if (_isDetecting) {
      _stopDetection();
    } else {
      _startDetection();
    }

    setState(() {
      _isDetecting = !_isDetecting;
    });
  }

  void _startDetection() {
    if (_cameraController != null && _isModelLoaded) {
      _processingTimer =
          Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _processFrame();
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera or model not ready')),
        );
      }
    }
  }

  void _stopDetection() {
    _processingTimer?.cancel();
    _blinkEvents.clear();
  }

  Future<void> _processFrame() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final image = await _cameraController!.takePicture();

      // Process with YOLO
      final detectionResults = await _yoloService.detectObjects(image.path);

      // Calculate EAR
      final earValue = _earCalculator.calculateEAR(detectionResults);

      // Detect blinks
      final blinkDetected = _blinkDetection.detectBlink(earValue);

      if (blinkDetected) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _blinkEvents.add({
          'timestamp': timestamp,
          'ear': earValue,
        });

        // Check for anomalies
        final isAnomalous = _anomalyDetection.detectAnomaly(_blinkEvents);

        if (isAnomalous) {
          // Handle anomaly detection
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Suspicious blink pattern detected!'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        setState(() {});
      }
    } catch (e) {
      debugPrint('Error processing frame: $e');
    }
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    // Stop detection if running
    if (_isDetecting) {
      _stopDetection();
      setState(() {
        _isDetecting = false;
      });
    }

    // Wait for camera to be properly disposed
    await _disposeCurrentCamera();

    setState(() {
      _isInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    });

    // Initialize new camera
    await _initializeCamera();
  }

  Future<void> _disposeCurrentCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopDetection();
      _disposeCurrentCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
      if (_isDetecting) {
        _startDetection();
      }
    }
  }

  @override
  void dispose() {
    _stopDetection();
    _disposeCurrentCamera();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A3990), Color(0xFF0B0B45)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Bridge Cheat Detection',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios,
                          color: Colors.white),
                      onPressed: _switchCamera,
                    ),
                  ],
                ),
              ),

              // Camera View
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _isInitialized
                          ? CameraView(
                              controller: _cameraController!,
                              detections: null, // Add your detection data here
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.2),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Starting camera...',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              // Result Display
              Expanded(
                flex: 2,
                child: ResultDisplay(
                  blinkEvents: _blinkEvents,
                  isAnomalous: _blinkEvents.isNotEmpty &&
                      _anomalyDetection.detectAnomaly(_blinkEvents),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleDetection,
        backgroundColor: _isDetecting ? Colors.red.shade800 : Colors.white,
        foregroundColor: _isDetecting ? Colors.white : const Color(0xFF2A3990),
        icon: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
        label: Text(
          _isDetecting ? 'Stop Detection' : 'Start Detection',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
