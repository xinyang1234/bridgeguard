class AnomalyDetection {
  // Time window for analysis in milliseconds
  final int _analysisWindowMs = 30000; // 30 seconds
  
  // Thresholds for anomaly detection
  final int _maxBlinksInWindow = 20; // More than 20 blinks in 30s is suspicious
  final int _minBlinksInWindow = 3;  // Less than 3 blinks in 30s is suspicious
  
  // Minimum time between blinks for pattern detection
  final int _minTimeBetweenBlinks = 200; // milliseconds
  
  // Pattern detection parameters
  final int _patternSequenceLength = 3; // Look for patterns of 3 blinks
  final double _patternSimilarityThreshold = 50.0; // milliseconds
  
  // Detect anomaly in blink patterns
  bool detectAnomaly(List<Map<String, dynamic>> blinkEvents) {
    if (blinkEvents.isEmpty) return false;
    
    // Too few events to analyze
    if (blinkEvents.length < _minBlinksInWindow) return false;
    
    // Get current time
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    // Filter events within analysis window
    final recentBlinkEvents = blinkEvents
        .where((event) => (currentTime - event['timestamp']) <= _analysisWindowMs)
        .toList();
    
    // Check for frequency anomalies
    if (recentBlinkEvents.length > _maxBlinksInWindow) {
      return true; // Too many blinks
    }
    
    if (recentBlinkEvents.length < _minBlinksInWindow && 
        (currentTime - blinkEvents.first['timestamp']) >= _analysisWindowMs) {
      return true; // Too few blinks over sufficient time
    }
    
    // Check for rhythmic patterns
    if (recentBlinkEvents.length >= _patternSequenceLength * 2) {
      return _detectRhythmicPatterns(recentBlinkEvents);
    }
    
    return false;
  }
  
  // Look for suspicious rhythmic patterns in blink sequences
  bool _detectRhythmicPatterns(List<Map<String, dynamic>> events) {
    // Calculate intervals between blinks
    List<int> intervals = [];
    for (int i = 1; i < events.length; i++) {
      final interval = events[i]['timestamp'] - events[i-1]['timestamp'];
      if (interval >= _minTimeBetweenBlinks) {
        intervals.add(interval);
      }
    }
    
    // Not enough intervals to analyze
    if (intervals.length < _patternSequenceLength * 2) {
      return false;
    }
    
    // Look for repeating interval patterns
    for (int i = 0; i <= intervals.length - _patternSequenceLength * 2; i++) {
      // Get first sequence
      List<int> sequence1 = intervals.sublist(i, i + _patternSequenceLength);
      
      // Compare with subsequent sequences
      for (int j = i + _patternSequenceLength; j <= intervals.length - _patternSequenceLength; j++) {
        List<int> sequence2 = intervals.sublist(j, j + _patternSequenceLength);
        
        // Check if sequences are similar
        bool similar = true;
        for (int k = 0; k < _patternSequenceLength; k++) {
          if ((sequence1[k] - sequence2[k]).abs() > _patternSimilarityThreshold) {
            similar = false;
            break;
          }
        }
        
        if (similar) {
          return true; // Found repetitive pattern
        }
      }
    }
    
    return false;
  }
}