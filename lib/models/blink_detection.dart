class BlinkDetection {
  // EAR threshold for detecting blinks
  final double _earThreshold = 0.2;
  
  // State variables to track blink state
  bool _previousBlinkState = false;
  int _consecutiveFramesBelow = 0;
  
  // Number of consecutive frames required to confirm blink
  final int _minBlinkFrames = 2;
  
  // Reset after some time without a blink
  int _framesSinceLastBlink = 0;
  final int _resetFrames = 10;
  
  // Detect a blink based on EAR value
  bool detectBlink(double earValue) {
    bool blinkDetected = false;
    
    // Increment frames since last blink counter
    _framesSinceLastBlink++;
    
    // Reset state if it's been too long since last blink event
    if (_framesSinceLastBlink > _resetFrames) {
      _consecutiveFramesBelow = 0;
      _previousBlinkState = false;
    }
    
    // Check if current EAR is below threshold
    bool currentBlinkState = earValue < _earThreshold;
    
    // Count consecutive frames below threshold
    if (currentBlinkState) {
      _consecutiveFramesBelow++;
    } else {
      // If we had enough consecutive frames and now eyes are open again,
      // we can consider it a complete blink
      if (_previousBlinkState && _consecutiveFramesBelow >= _minBlinkFrames) {
        blinkDetected = true;
        _framesSinceLastBlink = 0;
      }
      _consecutiveFramesBelow = 0;
    }
    
    _previousBlinkState = currentBlinkState;
    return blinkDetected;
  }
  
  // FUNGSI BARU: Hitung EAR dari landmark mata
  double calculateEAR(List<Map<String, int>> landmarks) {
    // Memastikan kita memiliki cukup landmark (minimal 6)
    if (landmarks.length < 6) {
      return 1.0; // Default ke mata terbuka jika landmark tidak cukup
    }
    
    // Mengasumsikan landmark berurutan sebagai:
    // 0: Left corner
    // 1: Top point
    // 2: Right corner
    // 3: Bottom point
    // 4: Center
    // 5: Pupil
    
    // Hitung jarak vertikal (tinggi mata)
    double height = (landmarks[1]['y']! - landmarks[3]['y']!).abs().toDouble();
    
    // Hitung jarak horizontal (lebar mata)
    double width = (landmarks[2]['x']! - landmarks[0]['x']!).abs().toDouble();
    
    // Hindari pembagian dengan nol
    if (width == 0) return 1.0;
    
    // Hitung EAR
    double ear = height / width;
    return ear;
  }
  
  // FUNGSI BARU: Proses deteksi mata dari YOLOv8
  bool processEyeDetections(List<Map<String, dynamic>> eyeDetections) {
    // Tidak ada mata terdeteksi
    if (eyeDetections.isEmpty) {
      return false;
    }
    
    // Hitung EAR rata-rata untuk semua mata yang terdeteksi
    double totalEAR = 0.0;
    int eyeCount = 0;
    
    for (final detection in eyeDetections) {
      if (detection.containsKey('landmarks')) {
        final landmarks = detection['landmarks'] as List<Map<String, int>>;
        final ear = calculateEAR(landmarks);
        
        totalEAR += ear;
        eyeCount++;
        
        // Log untuk debugging
        print('Eye detection - confidence: ${detection['confidence']}, EAR: $ear');
      }
    }
    
    // Hitung EAR rata-rata
    double averageEAR = eyeCount > 0 ? totalEAR / eyeCount : 1.0;
    
    // Deteksi kedipan menggunakan EAR
    return detectBlink(averageEAR);
  }
  
  // Reset the detector state
  void reset() {
    _previousBlinkState = false;
    _consecutiveFramesBelow = 0;
    _framesSinceLastBlink = 0;
  }
}