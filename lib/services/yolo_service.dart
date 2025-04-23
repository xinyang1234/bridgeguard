import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image/image.dart' as img;

class YoloService {
  late FlutterVision _vision;
  bool _isModelLoaded = false;
  
  Future<void> loadModel() async {
    _vision = FlutterVision();
    
    try {
      // Carregando o modelo YOLOv8 customizado para detecção de olhos
      await _vision.loadYoloModel(
        modelPath: "assets/models/yolov8n_float32.tflite",
        labels: "assets/models/labels.txt",
        modelVersion: "yolov8",
        quantization: false,
        numThreads: 2,
        useGpu: true,
      );
      
      _isModelLoaded = true;
      print('YOLO model loaded successfully');
    } catch (e) {
      print('Failed to load YOLO model: $e');
      _isModelLoaded = false;
    }
  }
  
  Future<List<Map<String, dynamic>>> detectEyes(CameraImage image) async {
    if (!_isModelLoaded) {
      print('Model not loaded yet');
      return [];
    }
    
    try {
      // Converter imagem da câmera para formato compatível
      final img.Image? convertedImage = _convertCameraImage(image);
      if (convertedImage == null) {
        return [];
      }
      
      // Executar detecção YOLOv8
      final results = await _vision.yoloOnImage(
        bytesList: img.encodeJpg(convertedImage),
        iouThreshold: 0.5,
        confThreshold: 0.3, imageWidth: 10, imageHeight: 10,
      );
      
      // Processar resultados e extrair landmarks dos olhos
      final processedResults = _processEyeDetections(results);
      return processedResults;
    } catch (e) {
      print('Error in eye detection: $e');
      return [];
    }
  }
  
  List<Map<String, dynamic>> _processEyeDetections(List<Map<String, dynamic>> detections) {
    List<Map<String, dynamic>> results = [];
    
    for (var detection in detections) {
      // Filtrar apenas as detecções de olhos
      if (detection['className'] == 'eye' || 
          detection['className'] == 'left_eye' || 
          detection['className'] == 'right_eye') {
        
        // Extrair coordenadas da bounding box
        final box = detection['box'];
        final double x1 = box[0];
        final double y1 = box[1];
        final double x2 = box[2];
        final double y2 = box[3];
        
        // Gerar pontos para cálculo do EAR (6 pontos para cada olho)
        // Esta é uma simplificação - em um sistema real, 
        // você teria um modelo específico para landmarks
        List<List<double>> landmarks = _generateEyeLandmarks(x1, y1, x2, y2);
        
        results.add({
          'rect': [x1, y1, x2, y2],
          'className': detection['className'],
          'confidence': detection['confidence'],
          'landmarks': landmarks,
        });
      }
    }
    
    return results;
  }
  
  List<List<double>> _generateEyeLandmarks(double x1, double y1, double x2, double y2) {
    // Calcular centro e dimensões
    double centerY = (y1 + y2) / 2;
    double width = x2 - x1;
    double height = y2 - y1;
    
    // Gerar 6 pontos aproximados para olho (simplificado)
    return [
      [x1 + width * 0.1, centerY], // Ponto esquerdo
      [x1 + width * 0.3, y1 + height * 0.3], // Superior esquerdo
      [x1 + width * 0.7, y1 + height * 0.3], // Superior direito
      [x2 - width * 0.1, centerY], // Ponto direito
      [x1 + width * 0.7, y2 - height * 0.3], // Inferior direito
      [x1 + width * 0.3, y2 - height * 0.3], // Inferior esquerdo
    ];
  }
  
  img.Image? _convertCameraImage(CameraImage image) {
    try {
      if (Platform.isAndroid) {
        // Para Android (formato YUV)
        final int width = image.width;
        final int height = image.height;
        final int uvRowStride = image.planes[1].bytesPerRow;
        final int uvPixelStride = image.planes[1].bytesPerPixel!;
        
        var img2 = img.Image(width: width, height: height);
        
        for (int x = 0; x < width; x++) {
          for (int y = 0; y < height; y++) {
            final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
            final int index = y * width + x;
            
            final yp = image.planes[0].bytes[index];
            final up = image.planes[1].bytes[uvIndex];
            final vp = image.planes[2].bytes[uvIndex];
            
            // Converter YUV para RGB
            int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
            int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
            int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
            
            // img2.data[index] = (0xFF << 24) | (r << 16) | (g << 8) | b;
            if (img2.data != null) {
              img2.setPixel(x, y, ((0xFF << 24) | (r << 16) | (g << 8) | b) as img.Color);
            }


          }
        }
        
        return img2;
      } else if (Platform.isIOS) {
        // Para iOS (formato BGRA)
        img.Image img2 = img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: image.planes[0].bytes.buffer,
          order: img.ChannelOrder.bgra,
        );
        return img2;
      }
    } catch (e) {
      print('Error converting camera image: $e');
    }

    return null;
  }
  
  void dispose() async {
    if (_isModelLoaded) {
      await _vision.closeYoloModel();
      print('YOLO model unloaded');
    }
  }
}