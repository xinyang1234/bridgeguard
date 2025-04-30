import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class YoloService {
  // Model file paths
  static const String _modelPath = 'assets/models/yolov8n_float32.tflite';
  static const String _labelsPath = 'assets/labels.txt';
  
  // TFLite model
  Interpreter? _interpreter;
  List<String>? _labels;
  
  // Input configuration
  final int _modelInputWidth = 640;
  final int _modelInputHeight = 640;
  final int _modelChannels = 3;
  
  // Output configuration for YOLOv8n
  // Using dynamic allocation to handle different model structures
  List<List<List<double>>>? _outputTensor;
  
  // Eye class index in labels
  int _eyeClassIndex = -1;
  
  // Confidence threshold
  final double _confidenceThreshold = 0.5;
  
  // Initialize model
  Future<void> loadModel() async {
    try {
      print('Loading YOLOv8 model...');
      
      // Load model
      final interpreterOptions = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true;
      
      // Load model from assets
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: interpreterOptions,
      );
      
      // Get model input and output shapes for debugging
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      
      print('YOLOv8 model loaded successfully');
      print('Input shape: ${inputTensors.map((t) => t.shape).toList()}');
      print('Output shape: ${outputTensors.map((t) => t.shape).toList()}');
      
      // Load labels
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData.split('\n')
          .where((label) => label.trim().isNotEmpty)
          .toList();
      
      print('Labels loaded: ${_labels!.length} labels');
      
      // Find eye class index
      _eyeClassIndex = _labels!.indexWhere(
        (label) => label.trim().toLowerCase() == 'eye'
      );
      
      print('Eye class index: $_eyeClassIndex');
      
      // Initialize output tensor with a simpler approach
      // This avoids the cast error by using a more direct tensor creation
      _initializeOutputTensor();
      
    } catch (e) {
      print('Error loading model: $e');
      rethrow;
    }
  }
  
  // Initialize output tensor based on model output shape
  void _initializeOutputTensor() {
    // For YOLOv8, we'll use a safe approach with a 3D tensor
    _outputTensor = List.generate(
      1, // Batch size
      (_) => List.generate(
        84, // 4 coordinates + 80 classes
        (_) => List.generate(8400, (_) => 0.0), // 8400 potential detections
      ),
    );
    
    print('Output tensor initialized with shape: [1, 84, 8400]');
  }
  
  // Detect objects in image
  Future<List<Map<String, dynamic>>> detectObjects(String imagePath) async {
    if (_interpreter == null) {
      throw Exception('Model not loaded');
    }
    
    try {
      // Read and preprocess image
      final imageFile = File(imagePath);
      final image = img.decodeImage(await imageFile.readAsBytes());
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      
      // Resize image
      final preprocessedImage = img.copyResize(
        image,
        width: _modelInputWidth,
        height: _modelInputHeight,
      );
      
      // Convert to input tensor
      final inputTensor = _imageToTensor(preprocessedImage);
      
      // Run inference with simplified approach
      print('Running inference...');
      
      // Using direct run method to avoid type casting issues
      _interpreter!.run(inputTensor[0], _outputTensor![0]);
      
      print('Inference complete, processing results...');
      
      // Process results
      return _processResults(
        image.width,
        image.height,
      );
    } catch (e) {
      print('Error during object detection: $e');
      rethrow;
    }
  }
  
  // Convert image to input tensor
  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    // Create empty tensor
    final tensor = List.generate(
      1, // Batch size
      (_) => List.generate(
        _modelInputHeight,
        (_) => List.generate(
          _modelInputWidth,
          (_) => List.generate(_modelChannels, (_) => 0.0),
        ),
      ),
    );
    
    // Fill tensor with image data
    for (int y = 0; y < _modelInputHeight; y++) {
      for (int x = 0; x < _modelInputWidth; x++) {
        final pixel = image.getPixel(x, y);
        
        // Normalize pixel values to [0, 1]
        tensor[0][y][x][0] = pixel.r / 255.0;
        tensor[0][y][x][1] = pixel.g / 255.0;
        tensor[0][y][x][2] = pixel.b / 255.0;
      }
    }
    
    return tensor;
  }
  
  // Process detection results
  List<Map<String, dynamic>> _processResults(
    int imageWidth,
    int imageHeight,
  ) {
    final List<Map<String, dynamic>> detections = [];
    
    try {
      print('Processing YOLOv8 results...');
      
      // Process each potential detection
      for (int i = 0; i < 8400; i++) {
        // Get box coordinates (first 4 values)
        final x = _outputTensor![0][0][i];
        final y = _outputTensor![0][1][i];
        final w = _outputTensor![0][2][i];
        final h = _outputTensor![0][3][i];
        
        // Find highest class confidence
        double maxScore = 0.0;
        int classId = -1;
        
        // Check all class scores (indices 4 to 83)
        for (int c = 0; c < 80; c++) {
          final score = _outputTensor![0][c + 4][i];
          if (score > maxScore) {
            maxScore = score;
            classId = c;
          }
        }
        
        // Filter by confidence and class (if eye class is found, only keep eye detections)
        if (maxScore >= _confidenceThreshold && 
            (_eyeClassIndex == -1 || classId == _eyeClassIndex)) {
          
          // Convert normalized coordinates to image coordinates
          final xmin = ((x - w / 2) * imageWidth).toInt();
          final ymin = ((y - h / 2) * imageHeight).toInt();
          final xmax = ((x + w / 2) * imageWidth).toInt();
          final ymax = ((y + h / 2) * imageHeight).toInt();
          
          // Clamp values to image boundaries
          final safeXmin = xmin.clamp(0, imageWidth - 1);
          final safeYmin = ymin.clamp(0, imageHeight - 1);
          final safeXmax = xmax.clamp(0, imageWidth - 1);
          final safeYmax = ymax.clamp(0, imageHeight - 1);
          
          // Only add if box is valid
          if (safeXmax > safeXmin && safeYmax > safeYmin) {
            detections.add({
              'class': _eyeClassIndex != -1 ? 'eye' : 
                       (_labels != null && classId < _labels!.length ? 
                        _labels![classId] : 'unknown'),
              'confidence': maxScore,
              'box': {
                'xmin': safeXmin,
                'ymin': safeYmin,
                'xmax': safeXmax,
                'ymax': safeYmax,
                'width': (safeXmax - safeXmin),
                'height': (safeYmax - safeYmin),
              },
              'landmarks': _estimateEyeLandmarks(safeXmin, safeYmin, safeXmax, safeYmax),
            });
          }
        }
      }
      
      print('Found ${detections.length} detections');
      return detections;
      
    } catch (e) {
      print('Error processing results: $e');
      return [];
    }
  }
  
  // Estimate eye landmarks based on bounding box
  List<Map<String, int>> _estimateEyeLandmarks(int xmin, int ymin, int xmax, int ymax) {
    final int width = xmax - xmin;
    final int height = ymax - ymin;
    
    // Simplify to 6 landmarks for eye:
    // 1. Left corner of eye
    // 2. Top point of eye
    // 3. Right corner of eye
    // 4. Bottom point of eye
    // 5. Center of eye
    // 6. Pupil (estimated)
    
    return [
      {'x': xmin, 'y': ymin + (height ~/ 2)},                 // Left corner
      {'x': xmin + (width ~/ 2), 'y': ymin},                  // Top point
      {'x': xmax, 'y': ymin + (height ~/ 2)},                 // Right corner
      {'x': xmin + (width ~/ 2), 'y': ymax},                  // Bottom point
      {'x': xmin + (width ~/ 2), 'y': ymin + (height ~/ 2)},  // Center
      {'x': xmin + (width ~/ 2), 'y': ymin + (height ~/ 2)},  // Pupil (estimated at center)
    ];
  }
  
  // Clean up resources
  void dispose() {
    _interpreter?.close();
  }
}