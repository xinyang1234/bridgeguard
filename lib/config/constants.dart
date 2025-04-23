import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2A3990);
  static const Color primaryDark = Color(0xFF0B0B45);
  static const Color accent = Color(0xFF00BCD4);
  static const Color background = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFFF5252);
  static const Color success = Color(0xFF4CAF50);
}

class AppConfig {
  // Configurações do YOLO
  static const String yoloModelPath = "assets/models/yolov8n_eye_detection.tflite";
  static const String yoloLabelsPath = "assets/models/labels.txt";
  
  // Configurações de detecção de piscar
  static const double earThreshold = 0.2;  // Limiar para considerar olho fechado
  static const int minFramesForBlink = 2;  // Frames mínimos para confirmar piscada
  static const int timeWindowSeconds = 30; // Janela de tempo para análise
  
  // Outras configurações
  static const int cameraResolutionPreset = 0; // 0: baixa, 1: média, 2: alta
  static const bool useFrontCamera = true;
}

class AppTextStyles {
  static TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );
  
  static TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );
  
  static TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
  
  static TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.textDark,
  );
  
  static TextStyle caption = TextStyle(
    fontSize: 14,
    color: AppColors.textDark.withOpacity(0.7),
  );
  
  static TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
  );
}