import 'dart:math';

class TimestampAnalyzer {
  // Analyze patterns in timestamps
  Map<String, dynamic> analyzeBlinkPattern(List<Map<String, dynamic>> blinkEvents) {
    if (blinkEvents.isEmpty) {
      return {
        'count': 0,
        'rate': 0.0,
        'pattern': 'No blinks detected',
        'suspicious': false
      };
    }
    
    // Calculate time span
    final firstTimestamp = blinkEvents.first['timestamp'] as int;
    final lastTimestamp = blinkEvents.last['timestamp'] as int;
    final timeSpanMs = (lastTimestamp - firstTimestamp).toDouble();
    
    // Calculate blink rate (blinks per minute)
    final count = blinkEvents.length;
    final blinkRate = timeSpanMs > 0 ? (count / (timeSpanMs / 60000)) : 0.0;
    
    // Analyze intervals between blinks
    final intervals = <int>[];
    for (int i = 1; i < blinkEvents.length; i++) {
      final interval = blinkEvents[i]['timestamp'] - blinkEvents[i-1]['timestamp'];
      intervals.add(interval);
    }
    
    // Calculate statistics for intervals
    final stats = _calculateStatistics(intervals);
    
    // Determine pattern type
    String pattern = 'Normal';
    bool suspicious = false;
    
    // Check for suspicious patterns
    if (count > 0) {
      if (blinkRate > 50) {
        pattern = 'Rapid blinking';
        suspicious = true;
      } else if (blinkRate < 5 && timeSpanMs > 30000) { // Less than 5 blinks per minute over 30+ seconds
        pattern = 'Very infrequent blinking';
        suspicious = true;
      } else if (stats['cv']! < 0.2 && intervals.length >= 3) { // Low coefficient of variation = rhythmic pattern
        pattern = 'Rhythmic blinking';
        suspicious = true;
      } else if (stats['cv']! > 1.0) { // High coefficient of variation = erratic pattern
        pattern = 'Erratic blinking';
        suspicious = false; // This is actually common in normal behavior
      }
    }
    
    return {
      'count': count,
      'rate': blinkRate,
      'avgInterval': stats['mean'],
      'stdDevInterval': stats['stdDev'],
      'pattern': pattern,
      'suspicious': suspicious
    };
  }
  
  // Calculate statistics for a list of values
  Map<String, double> _calculateStatistics(List<int> values) {
    if (values.isEmpty) {
      return {'mean': 0.0, 'stdDev': 0.0, 'cv': 0.0};
    }
    
    // Calculate mean
    final sum = values.reduce((a, b) => a + b);
    final mean = sum / values.length;
    
    // Calculate standard deviation
    double sumSquaredDiff = 0;
    for (final value in values) {
      sumSquaredDiff += pow(value - mean, 2);
    }
    final variance = sumSquaredDiff / values.length;
    final stdDev = sqrt(variance);
    
    // Calculate coefficient of variation (CV)
    final cv = mean > 0 ? stdDev / mean : 0.0;
    
    return {'mean': mean, 'stdDev': stdDev, 'cv': cv};
  }
}