import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class YoloService {
  // Model file paths
  static const String _modelPath = 'assets/models/best_saved_model/best_float32.tflite';
  static const String _labelsPath = 'assets/labels.txt';
  
  // TFLite model
  Interpreter? _interpreter;
  List<String>? _labels;
  
  // Input configuration for detection model
  final int _modelInputWidth = 640;
  final int _modelInputHeight = 640;
  final int _modelInputChannels = 3;
  
  // Output configuration for detection model
  List<List<List<double>>>? _outputTensor;
  
  // Class indices
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
      
      // Print input and output shapes
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      
      print('Model loaded successfully');
      print('Input shape: ${inputTensors.map((t) => t.shape).toList()}');
      print('Output shape: ${outputTensors.map((t) => t.shape).toList()}');
      
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
      
      // Initialize output tensor based on model output shape
      _initializeOutputTensor();
      
    } catch (e) {
      print('Error loading model: $e');
      rethrow;
    }
  }
  
  // Initialize output tensor 
  void _initializeOutputTensor() {
    // Based on output shape [1, 8, 8400]
    _outputTensor = List.generate(
      1, // Batch size
      (_) => List.generate(
        8, // Number of output channels/classes
        (_) => List.generate(8400, (_) => 0.0), // Detection count
      ),
    );
    
    print('Output tensor initialized');
  }
  
  // Detect objects 
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
      
      // Prepare output tensor
      final outputTensor = List.generate(
        1, 
        (_) => List.generate(
          8, 
          (_) => List.generate(8400, (_) => 0.0)
        )
      );
      
      // Run inference
      print('Running inference...');
      _interpreter!.run(inputTensor, outputTensor);
      
      print('Inference complete, processing results...');
      
      // Process results
      return _processResults(
        image.width,
        image.height,
        outputTensor[0],
      );
    } catch (e) {
      print('Error during object detection: $e');
      rethrow;
    }
  }
  
  // Convert image to input tensor 
  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    // Create tensor with NHWC format [1, height, width, channels]
    final tensor = List.generate(
      1, // Batch size
      (_) => List.generate(
        _modelInputHeight,
        (_) => List.generate(
          _modelInputWidth,
          (_) => List.generate(
            _modelInputChannels, // Channels last
            (_) => 0.0,
          ),
        ),
      ),
    );
    
    // Fill tensor with image data
    for (int y = 0; y < _modelInputHeight; y++) {
      for (int x = 0; x < _modelInputWidth; x++) {
        final pixel = image.getPixel(x, y);
        
        // Normalize pixel values
        tensor[0][y][x][0] = pixel.r / 255.0; // Red channel
        tensor[0][y][x][1] = pixel.g / 255.0; // Green channel
        tensor[0][y][x][2] = pixel.b / 255.0; // Blue channel
      }
    }
    
    // Debug print tensor shape
    print('Tensor shape: [${tensor.length}, ${tensor[0].length}, ${tensor[0][0].length}, ${tensor[0][0][0].length}]');
    
    return tensor;
  }
  
  // Process detection results
  List<Map<String, dynamic>> _processResults(
    int imageWidth,
    int imageHeight,
    List<List<double>> outputTensor,
  ) {
    final List<Map<String, dynamic>> detections = [];
    
    try {
      print('Processing detection results...');
      
      // Iterate through potential detections
      // Struktur output: [8, 8400]
      // Index 0-3: Box coordinates (x, y, width, height)
      // Index 4-7: Class confidences
      for (int i = 0; i < 8400; i++) { 
        // Get box coordinates 
        final x = outputTensor[0][i];
        final y = outputTensor[1][i];
        final w = outputTensor[2][i];
        final h = outputTensor[3][i];
        
        // Find highest class confidence
        double maxScore = 0.0;
        int classId = -1;
        
        // Check class confidences (indices 4-7)
        for (int c = 0; c < 4; c++) {
          final score = outputTensor[c + 4][i];
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