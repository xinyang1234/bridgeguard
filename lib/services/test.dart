import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class YoloService {
  // Model file paths - updated for specific model
  static const String _modelPath = 'assets/models/best_saved_model/best_float32.tflite';
  static const String _labelsPath = 'assets/labels.txt';
  
  // TFLite model
  Interpreter? _interpreter;
  List<String>? _labels;
  
  // Input configuration for detection model
  final int _modelInputWidth = 640;
  final int _modelInputHeight = 640;
  final int _modelChannels = 3;
  
  // Output configuration for detection model
  List<List<List<double>>>? _outputTensor;
  
  // Eye and state class indices
  int _eyeClassIndex = -1;
  int _pupilClassIndex = -1;
  int _drowsyClassIndex = -1;
  int _awakeClassIndex = -1;
  
  // Confidence threshold
  final double _confidenceThreshold = 0.45;
  
  // Initialize model
  Future<void> loadModel() async {
    try {
      print('Loading detection model...');
      
      // Load model with optimized settings
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
      
      print('Model loaded successfully');
      print('Input shape: ${inputTensors.map((t) => t.shape).toList()}');
      print('Output shape: ${outputTensors.map((t) => t.shape).toList()}');
      for (int i = 0; i < inputTensors.length; i++) {
      print('Input Tensor $i:');
      print('  Shape: ${inputTensors[i].shape}');
      print('  Type: ${inputTensors[i].type}');
    }
    
    for (int i = 0; i < outputTensors.length; i++) {
      print('Output Tensor $i:');
      print('  Shape: ${outputTensors[i].shape}');
      print('  Type: ${outputTensors[i].type}');
    }
      // Load labels
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData.split('\n')
          .where((label) => label.trim().isNotEmpty)
          .toList();
      
      print('Labels loaded: ${_labels!.length} labels');
      
      // Find class indices
      _eyeClassIndex = _labels!.indexWhere(
        (label) => label.trim().toLowerCase() == 'iris'
      );
      _pupilClassIndex = _labels!.indexWhere(
        (label) => label.trim().toLowerCase() == 'pupil'
      );
      _drowsyClassIndex = _labels!.indexWhere(
        (label) => label.trim().toLowerCase() == 'drowsy'
      );
      _awakeClassIndex = _labels!.indexWhere(
        (label) => label.trim().toLowerCase() == 'awake'
      );
      
      print('Class indices:');
      print('Eye: $_eyeClassIndex');
      print('Pupil: $_pupilClassIndex');
      print('Drowsy: $_drowsyClassIndex');
      print('Awake: $_awakeClassIndex');
      print('Available labels: $_labels');
      
      // Initialize output tensor 
      _initializeOutputTensor();
      
    } catch (e) {
      print('Error loading model: $e');
      rethrow;
    }
  }
  
  // Initialize output tensor based on model output shape
  void _initializeOutputTensor() {
    // Adjust dimensions based on actual model output
    _outputTensor = List.generate(
      1, // Batch size
      (_) => List.generate(
        84, // Adjust based on your model's output structure
        (_) => List.generate(8400, (_) => 0.0), // Detection count
      ),
    );
    
    print('Output tensor initialized');
  }
  
  // Detect objects with model-specific processing
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
      
      // Convert to input tensor with specific preprocessing
      final inputTensor = _imageToTensor(preprocessedImage);
      
      // Run inference
      print('Running inference...');
      _interpreter!.run(inputTensor, _outputTensor!);
      
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
  
  // Convert image to input tensor with specific normalization
List<List<List<List<double>>>> _imageToTensor(img.Image image) {
  final tensor = List.generate(
    1, // Batch size
    (_) => List.generate(
      _modelInputHeight,
      (_) => List.generate(
        _modelInputWidth,
        (_) => List.generate(
          _modelChannels, // Pindahkan channel ke akhir
          (_) => 0.0,
        ),
      ),
    ),
  );
  
  // Fill tensor dengan urutan [height, width, channels]
  for (int y = 0; y < _modelInputHeight; y++) {
    for (int x = 0; x < _modelInputWidth; x++) {
      final pixel = image.getPixel(x, y);
      
      // Normalisasi
      tensor[0][y][x][0] = pixel.r / 255.0; // Red
      tensor[0][y][x][1] = pixel.g / 255.0; // Green
      tensor[0][y][x][2] = pixel.b / 255.0; // Blue
    }
  }
  
  print('Tensor shape: [${tensor.length}, ${tensor[0].length}, ${tensor[0][0].length}, ${tensor[0][0][0].length}]');
  return tensor;
}
  
  // Process detection results
  List<Map<String, dynamic>> _processResults(
    int imageWidth,
    int imageHeight,
  ) {
    final List<Map<String, dynamic>> detections = [];
    
    try {
      print('Processing detection results...');
      
      // Iterate through potential detections
      for (int i = 0; i < 8400; i++) { 
        // Get box coordinates 
        final x = _outputTensor![0][0][i];
        final y = _outputTensor![0][1][i];
        final w = _outputTensor![0][2][i];
        final h = _outputTensor![0][3][i];
        
        // Find highest class confidence
        double maxScore = 0.0;
        int classId = -1;
        
        // Check all class scores 
        for (int c = 0; c < 80; c++) {
          final score = _outputTensor![0][c + 4][i];
          if (score > maxScore) {
            maxScore = score;
            classId = c;
          }
        }
        
        // Apply post-processing
        if (maxScore >= _confidenceThreshold) {
          // Convert coordinates 
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
            // Determine detection class
            String detectedClass = 'unknown';
            if (_labels != null && classId < _labels!.length) {
              detectedClass = _labels![classId];
            }
            
            detections.add({
              'class': detectedClass,
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
  
  // Estimate eye landmarks
  List<Map<String, int>> _estimateEyeLandmarks(int xmin, int ymin, int xmax, int ymax) {
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