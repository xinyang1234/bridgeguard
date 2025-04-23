class BlinkDetector {
  final double earThreshold;
  final Function(int timestamp) onBlinkDetected;
  
  bool _isBlinking = false;
  int _blinkStartTimestamp = 0;
  int _consecutiveFramesBelowThreshold = 0;
  int _consecutiveFramesAboveThreshold = 0;
  
  // Constantes para filtrar falsos positivos
  static const int MIN_FRAMES_FOR_BLINK = 2; // Mínimo de frames consecutivos abaixo do threshold
  static const int MIN_FRAMES_BETWEEN_BLINKS = 5; // Mínimo de frames acima do threshold entre piscadas
  
  BlinkDetector({
    required this.earThreshold,
    required this.onBlinkDetected,
  });
  
  void processEAR(double earValue, int timestamp) {
    if (earValue < earThreshold) {
      // Valor de EAR abaixo do threshold (possível piscar)
      _consecutiveFramesBelowThreshold++;
      _consecutiveFramesAboveThreshold = 0;
      
      if (!_isBlinking && _consecutiveFramesBelowThreshold >= MIN_FRAMES_FOR_BLINK) {
        _isBlinking = true;
        _blinkStartTimestamp = timestamp;
      }
    } else {
      // Valor de EAR acima do threshold (olho aberto)
      _consecutiveFramesAboveThreshold++;
      _consecutiveFramesBelowThreshold = 0;
      
      if (_isBlinking && _consecutiveFramesAboveThreshold >= MIN_FRAMES_BETWEEN_BLINKS) {
        // Piscada completa detectada
        _isBlinking = false;
        onBlinkDetected(_blinkStartTimestamp);
      }
    }
  }
}

class AnomalyDetector {
  final List<int> _blinkTimestamps = [];
  final int timeWindowMs; // Janela de tempo para análise (em ms)
  
  AnomalyDetector({
    this.timeWindowMs = 30000, // 30 segundos por padrão
  });
  
  void addBlinkTimestamp(int timestamp) {
    _blinkTimestamps.add(timestamp);
    
    // Remover timestamps antigos fora da janela de análise
    _cleanOldData(timestamp);
  }
  
  void _cleanOldData(int currentTimestamp) {
    _blinkTimestamps.removeWhere(
      (ts) => currentTimestamp - ts > timeWindowMs
    );
  }
  
  bool detectRhythmicPattern() {
    if (_blinkTimestamps.length < 4) {
      return false; // Precisa de pelo menos 4 piscadas para análise
    }
    
    // Calcular intervalos entre piscadas
    List<int> intervals = [];
    for (int i = 1; i < _blinkTimestamps.length; i++) {
      intervals.add(_blinkTimestamps[i] - _blinkTimestamps[i-1]);
    }
    
    // Procurar padrões rítmicos (exemplo: 3 intervalos similares consecutivos)
    int similarIntervalCount = 0;
    for (int i = 1; i < intervals.length; i++) {
      double ratio = intervals[i] / intervals[i-1];
      
      // Intervalos são considerados similares se a razão estiver entre 0.8 e 1.2 (20% de tolerância)
      if (ratio >= 0.8 && ratio <= 1.2) {
        similarIntervalCount++;
        
        // Detectar sequência de 3 intervalos similares
        if (similarIntervalCount >= 2) {
          return true;
        }
      } else {
        similarIntervalCount = 0;
      }
    }
    
    // Procurar padrões repetitivos
    return _detectRepetitiveSequence(intervals);
  }
  
  bool _detectRepetitiveSequence(List<int> intervals) {
    // Implementação básica para detectar sequências repetitivas
    // Por exemplo: curto-longo-curto-longo
    
    if (intervals.length < 6) return false;
    
    for (int i = 0; i < intervals.length - 4; i++) {
      // Verificar se existe um padrão de 2 intervalos que se repete
      double ratio1 = intervals[i+2] / intervals[i];
      double ratio2 = intervals[i+3] / intervals[i+1];
      
      if ((ratio1 >= 0.8 && ratio1 <= 1.2) && (ratio2 >= 0.8 && ratio2 <= 1.2)) {
        return true;
      }
    }
    
    return false;
  }
  
  Map<String, dynamic> getBlinkStats() {
    if (_blinkTimestamps.isEmpty) {
      return {
        'count': 0,
        'frequency': 0.0,
        'rhythmic_pattern': false,
      };
    }
    
    int timespan = _blinkTimestamps.last - _blinkTimestamps.first;
    double frequencyPerMinute = timespan > 0 
        ? (_blinkTimestamps.length * 60000) / timespan 
        : 0;
    
    return {
      'count': _blinkTimestamps.length,
      'frequency': frequencyPerMinute,
      'rhythmic_pattern': detectRhythmicPattern(),
    };
  }
}