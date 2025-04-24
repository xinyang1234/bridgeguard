import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'Bridge Cheat Detector';
  static const String appVersion = '1.0.0';
  
  // Detection Parameters
  static const double earThreshold = 0.2; // EAR threshold for blink detection
  static const int minBlinkFrames = 2; // Minimum consecutive frames for a blink
  static const int analysisWindowMs = 30000; // 30 seconds window for analysis
  
  // UI Constants
  static const Duration splashScreenDuration = Duration(seconds: 3);
  static const double defaultPadding = 16.0;
  
  // Colors
  static const Color primaryColor = Color(0xFF4527A0);
  static const Color accentColor = Color(0xFF7E57C2);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color dangerColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  
  // Assets
  static const String yoloModelAsset = 'assets/yolov8n.tflite';
  static const String yoloLabelsAsset = 'assets/labels.txt';
  
  // Messages
  static const String noDetectionMessage = 'No eye detection yet';
  static const String normalBlinkMessage = 'Normal blinking pattern';
  static const String suspiciousBlinkMessage = 'Suspicious blinking pattern detected!';
  static const String loadingModelMessage = 'Loading YOLOv8 model...';
  static const String modelLoadedMessage = 'Model loaded successfully';
  static const String cameraInitErrorMessage = 'Camera initialization failed';
}