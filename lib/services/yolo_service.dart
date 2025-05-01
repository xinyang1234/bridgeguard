import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class YoloService {
  // Model file paths - update to YOLOv11
  static const String _modelPath = 'assets/models/best_saved_model/best_float32.tflite';
  static const String _labelsPath = 'assets/labels.txt';
  
  // TFLite model
  Interpreter? _interpreter;
  List<String>? _labels;
  
  // Input configuration for YOLOv11
  final int _modelInputWidth = 640;  // Sesuaikan dengan YOLOv11 requirements
  final int _modelInputHeight = 640; // Sesuaikan dengan YOLOv11 requirements
  final int _modelChannels = 3;
  
  // Output configuration for YOLOv11
  // YOLOv11 memiliki output format yang berbeda dari YOLOv8
  List<List<List<double>>>? _outputTensor;
  
  // Eye class index in labels
  int _eyeClassIndex = -1;
  
  // Confidence threshold - might need adjustment for YOLOv11
  final double _confidenceThreshold = 0.45;
  
  // Initialize model
  Future<void> loadModel() async {
    try {
      print('Loading YOLOv11 model...');
      
      // Load model with optimized settings for YOLOv11
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
      
      print('YOLOv11 model loaded successfully');
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
        (label) => label.trim().toLowerCase() == 'iris'
      );
      
      print('Eye class index: $_eyeClassIndex');
      print('Available labels: $_labels');
      
      // Initialize output tensor for YOLOv11
      _initializeOutputTensor();
      
    } catch (e) {
      print('Error loading model: $e');
      rethrow;
    }
  }
  
  // Initialize output tensor based on YOLOv11 output shape
  void _initializeOutputTensor() {
    // YOLOv11 output shape may differ from YOLOv8
    // You'll need to adjust these dimensions based on the actual model
    _outputTensor = List.generate(
      1, // Batch size
      (_) => List.generate(
        84, // 4 coordinates + 80 classes (adjust if YOLOv11 has different class count)
        (_) => List.generate(8400, (_) => 0.0), // Adjust detection count for YOLOv11
      ),
    );
    
    print('Output tensor initialized for YOLOv11');
  }
  
  // Detect objects with YOLOv11-specific processing
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
      
      // Convert to input tensor with YOLOv11 specific preprocessing
      final inputTensor = _imageToTensor(preprocessedImage);
      
      // Run inference
      print('Running YOLOv11 inference...');
      _interpreter!.run(inputTensor[0], _outputTensor![0]);
      
      print('YOLOv11 inference complete, processing results...');
      
      // Process YOLOv11 results
      return _processResults(
        image.width,
        image.height,
      );
    } catch (e) {
      print('Error during YOLOv11 object detection: $e');
      rethrow;
    }
  }
  
  // Convert image to input tensor with YOLOv11-specific normalization
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
    
    // Fill tensor with image data using YOLOv11 specific preprocessing
    for (int y = 0; y < _modelInputHeight; y++) {
      for (int x = 0; x < _modelInputWidth; x++) {
        final pixel = image.getPixel(x, y);
        
        // YOLOv11 might use different normalization
        tensor[0][y][x][0] = pixel.r / 255.0;
        tensor[0][y][x][1] = pixel.g / 255.0;
        tensor[0][y][x][2] = pixel.b / 255.0;
      }
    }
    
    return tensor;
  }
  
  // Process YOLOv11 detection results
  List<Map<String, dynamic>> _processResults(
    int imageWidth,
    int imageHeight,
  ) {
    final List<Map<String, dynamic>> detections = [];
    
    try {
      print('Processing YOLOv11 results...');
      
      // YOLOv11 might have different output structure
      // You'll need to adjust this processing based on the actual model output
      for (int i = 0; i < 8400; i++) { // Adjust count for YOLOv11
        // Get box coordinates 
        final x = _outputTensor![0][0][i];
        final y = _outputTensor![0][1][i];
        final w = _outputTensor![0][2][i];
        final h = _outputTensor![0][3][i];
        
        // Find highest class confidence
        double maxScore = 0.0;
        int classId = -1;
        
        // Check all class scores - YOLOv11 might have different class count
        for (int c = 0; c < 80; c++) {
          final score = _outputTensor![0][c + 4][i];
          if (score > maxScore) {
            maxScore = score;
            classId = c;
          }
        }
        
        // Apply YOLOv11 specific post-processing
        if (maxScore >= _confidenceThreshold && 
            (_eyeClassIndex == -1 || classId == _eyeClassIndex)) {
          
          // Convert coordinates - YOLOv11 might use different coordinate format
          final xmin = ((x - w / 2) * imageWidth).toInt();
          final ymin = ((y - h / 2) * imageHeight).toInt();
          final xmax = ((x + w / 2) * imageWidth).toInt();
          final ymax = ((y + h / 2) * imageHeight).toInt();
          
          // Safe bounds
          final safeXmin = xmin.clamp(0, imageWidth - 1);
          final safeYmin = ymin.clamp(0, imageHeight - 1);
          final safeXmax = xmax.clamp(0, imageWidth - 1);
          final safeYmax = ymax.clamp(0, imageHeight - 1);
          
          // Add valid detections
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
      
      print('Found ${detections.length} detections with YOLOv11');
      return detections;
      
    } catch (e) {
      print('Error processing YOLOv11 results: $e');
      return [];
    }
  }
  
  // Metode landmark estimation tetap sama
  List<Map<String, int>> _estimateEyeLandmarks(int xmin, int ymin, int xmax, int ymax) {
    // ... kode yang ada tetap sama
    final int width = xmax - xmin;
    final int height = ymax - ymin;
    
    return [
      {'x': xmin, 'y': ymin + (height ~/ 2)},                 // Left corner
      {'x': xmin + (width ~/ 2), 'y': ymin},                  // Top point
      {'x': xmax, 'y': ymin + (height ~/ 2)},                 // Right corner
      {'x': xmin + (width ~/ 2), 'y': ymax},                  // Bottom point
      {'x': xmin + (width ~/ 2), 'y': ymin + (height ~/ 2)},  // Center
      {'x': xmin + (width ~/ 2), 'y': ymin + (height ~/ 2)},  // Pupil (estimated at center)
    ];
  }
  
  void dispose() {
    _interpreter?.close();
  }
}