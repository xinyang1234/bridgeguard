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
  late List<List<List<double>>> _outputBoxes;
  late List<List<double>> _outputScores;
  late List<List<double>> _outputClasses;
  late List<double> _outputCount;
  
  // Confidence threshold
  final double _confidenceThreshold = 0.5;
  
  // Initialize model
  Future<void> loadModel() async {
    try {
      // Load model
      final interpreterOptions = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true;
      
      // Load model from assets
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: interpreterOptions,
      );
      
      // Load labels
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData.split('\n');
      
      // Initialize output tensors
      _outputBoxes = List.generate(
        1, // Batch size
        (_) => List.generate(
          100, // Max detections
          (_) => List.generate(4, (_) => 0.0), // [x, y, w, h]
        ),
      );
      
      _outputScores = List.generate(
        1, // Batch size
        (_) => List.generate(100, (_) => 0.0), // Max detections
      );
      
      _outputClasses = List.generate(
        1, // Batch size
        (_) => List.generate(100, (_) => 0.0), // Max detections
      );
      
      _outputCount = List.generate(1, (_) => 0.0);
      
      print('YOLOv8 model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
      rethrow;
    }
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
      
      // Convert to float32 tensor
      final inputTensor = _imageToTensor(preprocessedImage);
      
      // Define output shapes
      final outputMap = {
        0: _outputBoxes,
        1: _outputScores,
        2: _outputClasses,
        3: _outputCount,
      };
      
      // Run inference
      _interpreter!.runForMultipleInputs([inputTensor], outputMap);
      
      // Process results
      return _processResults(
        image.width,
        image.height,
        _outputBoxes[0],
        _outputScores[0],
        _outputClasses[0],
        _outputCount[0].toInt(),
      );
    } catch (e) {
      print('Error during object detection: $e');
      return [];
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
    List<List<double>> boxes,
    List<double> scores,
    List<double> classes,
    int count,
  ) {
    final List<Map<String, dynamic>> detections = [];
    
    for (int i = 0; i < count; i++) {
      if (scores[i] < _confidenceThreshold) continue;
      
      final classId = classes[i].toInt();
      final className = _labels != null && classId < _labels!.length
          ? _labels![classId]
          : 'Unknown';
      
      // We're only interested in eye detections
      if (className.toLowerCase() != 'eye') continue;
      
      // YOLOv8 outputs [x_center, y_center, width, height]
      final x = boxes[i][0];
      final y = boxes[i][1];
      final w = boxes[i][2];
      final h = boxes[i][3];
      
      // Convert normalized coordinates to actual image coordinates
      final xmin = ((x - w / 2) * imageWidth).toInt();
      final ymin = ((y - h / 2) * imageHeight).toInt();
      final xmax = ((x + w / 2) * imageWidth).toInt();
      final ymax = ((y + h / 2) * imageHeight).toInt();
      
      detections.add({
        'class': className,
        'confidence': scores[i],
        'box': {
          'xmin': xmin,
          'ymin': ymin,
          'xmax': xmax,
          'ymax': ymax,
          'width': (xmax - xmin),
          'height': (ymax - ymin),
        },
        // Add eye landmarks (simplified for this example)
        'landmarks': _estimateEyeLandmarks(xmin, ymin, xmax, ymax),
      });
    }
    
    return detections;
  }
  
  // Estimate eye landmarks based on bounding box
  // In a real implementation, you would use a specialized landmark detection model
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