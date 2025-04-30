import 'dart:math';

class EARCalculator {
  // Calculate Euclidean distance between two points
  double _distance(Map<String, int> p1, Map<String, int> p2) {
    return sqrt(pow(p2['x']! - p1['x']!, 2) + pow(p2['y']! - p1['y']!, 2));
  }
  
  // Calculate Eye Aspect Ratio (EAR)
  // EAR = (||p2-p6|| + ||p3-p5||) / (2 * ||p1-p4||)
  double calculateEAR(List<Map<String, dynamic>> detections) {
    if (detections.isEmpty) {
      return 1.0; // Default value for open eyes
    }
    
    // Debug log
    print("Processing ${detections.length} detections for EAR calculation");
    
    double totalEAR = 0.0;
    int eyeCount = 0;
    
    for (final detection in detections) {
      // Debug: log detection details
      print("Detection class: ${detection['class']}, confidence: ${detection['confidence']}");
      
      // PERUBAHAN: 
      // Kita tidak perlu memeriksa 'class' == 'eye' karena YoloService sudah memfilter
      // hanya untuk deteksi mata, tapi kita tetap memastikan ada landmark
      if (detection.containsKey('landmarks')) {
        final landmarks = detection['landmarks'] as List<Map<String, int>>;
        
        // Debug: log landmark count
        print("Landmarks count: ${landmarks.length}");
        
        // Ensure we have enough landmarks
        if (landmarks.length >= 6) {
          // Calculate vertical distances
          final p1 = landmarks[0]; // Left corner
          final p2 = landmarks[1]; // Top point
          final p3 = landmarks[2]; // Right corner
          final p4 = landmarks[3]; // Bottom point
          final p5 = landmarks[4]; // Center
          final p6 = landmarks[5]; // Pupil
          
          // Calculate distances
          final verticalDist1 = _distance(p2, p4); // Top to bottom
          final horizontalDist = _distance(p1, p3); // Left to right
          
          // Debug: log distances
          print("Vertical distance: $verticalDist1, Horizontal distance: $horizontalDist");
          
          // Avoid division by zero
          if (horizontalDist > 0) {
            final ear = verticalDist1 / horizontalDist;
            totalEAR += ear;
            eyeCount++;
            
            // Debug: log EAR
            print("Calculated EAR: $ear");
          }
        }
      }
    }
    
    // Return average EAR if we detected eyes, otherwise default to open eyes
    double finalEAR = eyeCount > 0 ? totalEAR / eyeCount : 1.0;
    print("Final average EAR: $finalEAR from $eyeCount valid eye detections");
    return finalEAR;
  }
}