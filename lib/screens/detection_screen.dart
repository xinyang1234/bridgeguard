import 'package:bridge_cheat_detector/utils/ear_calculator.dart' as utils;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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

class _DetectionScreenState extends State<DetectionScreen> with WidgetsBindingObserver {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load detection model: $e')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cameras found')),
        );
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera initialization error: $e')),
      );
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
      _processingTimer = Timer.periodic(const Duration(milliseconds: 100), () {
        _processFrame();
      } as void Function(Timer timer));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera or model not ready')),
      );
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
  
  void _switchCamera() {
    if (_cameras == null || _cameras!.isEmpty) return;
    
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    _disposeCurrentCamera();
    _initializeCamera();
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
      appBar: AppBar(
        title: const Text('Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _isInitialized
                ? CameraView(controller: _cameraController!)
                : const Center(child: CircularProgressIndicator()),
          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleDetection,
        backgroundColor: _isDetecting ? Colors.red : Colors.green,
        child: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}