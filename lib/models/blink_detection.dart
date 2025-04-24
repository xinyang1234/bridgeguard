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
  
  // Reset the detector state
  void reset() {
    _previousBlinkState = false;
    _consecutiveFramesBelow = 0;
    _framesSinceLastBlink = 0;
  }
}