import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../config/constants.dart';

class CameraView extends StatelessWidget {
  final CameraController controller;
  final List<Map<String, dynamic>>? detections;
  
  const CameraView({
    Key? key,
    required this.controller,
    this.detections,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Stack(
      children: [
        // Camera preview
        Center(
          child: CameraPreview(controller),
        ),
        
        // Detection boxes overlay
        if (detections != null && detections!.isNotEmpty)
          CustomPaint(
            size: Size.infinite,
            painter: DetectionPainter(
              detections: detections!,
              previewSize: controller.value.previewSize!,
              screenSize: MediaQuery.of(context).size,
            ),
          ),
          
        // Status indicator
        Positioned(
          top: 10,
          right: 10, 
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: controller.value.isStreamingImages 
                        ? AppConstants.successColor 
                        : AppConstants.warningColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  controller.value.isStreamingImages ? 'Live' : 'Paused',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size previewSize;
  final Size screenSize;
  
  DetectionPainter({
    required this.detections,
    required this.previewSize,
    required this.screenSize,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint boxPaint = Paint()
      ..color = AppConstants.primaryColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
      
    final Paint landmarkPaint = Paint()
      ..color = AppConstants.accentColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;
    
    // Calculate scaling factors
    final double scaleX = screenSize.width / previewSize.width;
    final double scaleY = screenSize.height / previewSize.height;
    final double scale = math.min(scaleX, scaleY);
    
    // Calculate padding to center the preview
    final double offsetX = (screenSize.width - previewSize.width * scale) / 2;
    final double offsetY = (screenSize.height - previewSize.height * scale) / 2;
    
    for (final detection in detections) {
      if (detection.containsKey('box')) {
        final box = detection['box'] as Map<String, dynamic>;
        final confidence = detection['confidence'] as double;
        
        // Convert coordinates to screen space
        final Rect rect = Rect.fromLTWH(
          offsetX + box['xmin'] * scale,
          offsetY + box['ymin'] * scale,
          box['width'] * scale,
          box['height'] * scale,
        );
        
        // Draw bounding box
        canvas.drawRect(rect, boxPaint);
        
        // Draw label
        final textSpan = TextSpan(
          text: 'Eye: ${(confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
        
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        // Draw label background
        final backgroundRect = Rect.fromLTWH(
          rect.left,
          rect.top - 20,
          textPainter.width + 8,
          20,
        );
        
        canvas.drawRect(
          backgroundRect,
          Paint()..color = AppConstants.primaryColor.withOpacity(0.8),
        );
        
        // Draw label text
        textPainter.paint(canvas, Offset(rect.left + 4, rect.top - 18));
        
        // Draw landmarks if available
        if (detection.containsKey('landmarks')) {
          final landmarks = detection['landmarks'] as List<Map<String, int>>;
          for (final landmark in landmarks) {
            final x = offsetX + landmark['x']! * scale;
            final y = offsetY + landmark['y']! * scale;
            canvas.drawCircle(Offset(x, y), 2, landmarkPaint);
          }
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}