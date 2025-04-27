import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../config/constants.dart';

class CameraView extends StatefulWidget {
  final CameraController controller;
  final List<Map<String, dynamic>>? detections;

  const CameraView({
    Key? key,
    required this.controller,
    this.detections,
  }) : super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  double _currentZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeZoomLevels();
  }

  Future<void> _initializeZoomLevels() async {
    _maxZoomLevel = await widget.controller.getMaxZoomLevel();
    setState(() {});
  }

  @override
Widget build(BuildContext context) {
  if (!widget.controller.value.isInitialized) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  final previewSize = widget.controller.value.previewSize;
  if (previewSize == null) {
    return const Center(
      child: Text('Camera preview size is not available'),
    );
  }

  return Stack(
    children: [
      // Camera preview
      Center(
        child: CameraPreview(widget.controller),
      ),

      // Detection boxes overlay
      if (widget.detections != null && widget.detections!.isNotEmpty)
        CustomPaint(
          size: Size.infinite,
          painter: DetectionPainter(
            detections: widget.detections!,
            previewSize: previewSize,
            screenSize: MediaQuery.of(context).size,
          ),
        ),

      // Zoom controls
      Positioned(
        bottom: 20,
        left: 20,
        child: Column(
          children: [
            // Zoom In Button
            IconButton(
              icon: const Icon(Icons.zoom_in, color: Colors.white),
              onPressed: () async {
                final newZoomLevel = (_currentZoomLevel + 0.5).clamp(1.0, _maxZoomLevel);
                await _setZoomLevel(newZoomLevel);
              },
            ),
            const SizedBox(height: 10),
            // Zoom Out Button
            IconButton(
              icon: const Icon(Icons.zoom_out, color: Colors.white),
              onPressed: () async {
                final newZoomLevel = (_currentZoomLevel - 0.5).clamp(1.0, _maxZoomLevel);
                await _setZoomLevel(newZoomLevel);
              },
            ),
          ],
        ),
      ),

      // Zoom level indicator
      Positioned(
        bottom: 20,
        right: 20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_currentZoomLevel.toStringAsFixed(1)}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ),
    ],
  );
}

Future<void> _setZoomLevel(double zoom) async {
  zoom = zoom.clamp(1.0, _maxZoomLevel);
  try {
    await widget.controller.setZoomLevel(zoom);
    setState(() {
      _currentZoomLevel = zoom;
    });
  } catch (e) {
    debugPrint('Error setting zoom level: $e');
  }
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
