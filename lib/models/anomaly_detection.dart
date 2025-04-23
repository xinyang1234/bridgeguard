class AnomalyPattern {
  final List<int> _blinkTimestamps = [];
  final List<double> _earValues = [];
  final int _timeWindow; // Janela de tempo em milissegundos
  
  AnomalyPattern({int timeWindow = 30000}) : _timeWindow = timeWindow;
  
  void addBlinkEvent(int timestamp, double earValue) {
    _blinkTimestamps.add(timestamp);
    _earValues.add(earValue);
    
    // Limpar dados antigos fora da janela de tempo
    _cleanOldData(timestamp);
  }
  
  void _cleanOldData(int currentTime) {
    while (_blinkTimestamps.isNotEmpty && 
           currentTime - _blinkTimestamps.first > _timeWindow) {
      _blinkTimestamps.removeAt(0);
      _earValues.removeAt(0);
    }
  }
  
  bool detectAnomalyPatterns() {
    if (_blinkTimestamps.length < 4) {
      return false; // Precisa de pelo menos 4 piscar para análise
    }
    
    // Calcular tempos entre piscadas
    List<int> intervals = [];
    for (int i = 1; i < _blinkTimestamps.length; i++) {
      intervals.add(_blinkTimestamps[i] - _blinkTimestamps[i-1]);
    }
    
    // Detectar padrões rítmicos
    if (_detectRhythmicPattern(intervals)) {
      return true;
    }
    
    // Detectar padrões de grupo
    if (_detectGroupPattern(intervals)) {
      return true;
    }
    
    // Verificar frequência anormal
    if (_detectAbnormalFrequency()) {
      return true;
    }
    
    return false;
  }
  
  bool _detectRhythmicPattern(List<int> intervals) {
    // Procurar por intervalos regulares
    if (intervals.length < 3) return false;
    
    List<double> variationRatios = [];
    for (int i = 1; i < intervals.length; i++) {
      // Relação entre intervalos sucessivos
      variationRatios.add(intervals[i] / intervals[i-1]);
    }
    
    int similarCount = 0;
    for (int i = 0; i < variationRatios.length; i++) {
      double ratio = variationRatios[i];
      
      // Se a razão está próxima de 1 (intervalos similares)
      if (ratio >= 0.8 && ratio <= 1.2) {
        similarCount++;
        if (similarCount >= 2) { // 3 intervalos similares consecutivos
          return true;
        }
      } else {
        similarCount = 0;
      }
    }
    
    return false;
  }
  
  bool _detectGroupPattern(List<int> intervals) {
    // Procurar por grupos de piscadas seguidos por pausas
    if (intervals.length < 4) return false;
    
    // Classificar intervalos em curtos e longos
    double medianInterval = _calculateMedian(intervals);
    List<String> patternSequence = [];
    
    for (int interval in intervals) {
      if (interval < medianInterval * 0.7) {
        patternSequence.add('S'); // Intervalo curto
      } else if (interval > medianInterval * 1.5) {
        patternSequence.add('L'); // Intervalo longo
      } else {
        patternSequence.add('M'); // Intervalo médio
      }
    }
    
    // Procurar padrões como "SSLS" (3 curtos, 1 longo, 3 curtos)
    String patternStr = patternSequence.join('');
    
    // Padrões suspeitos que podem indicar comunicação
    List<String> suspiciousPatterns = [
      'SSLSS', 'SSSLS', 'SLSSS', 'LSSSL', 'SSSSL', 'LSSSS'
    ];
    
    for (String pattern in suspiciousPatterns) {
      if (patternStr.contains(pattern)) {
        return true;
      }
    }
    
    return false;
  }
  
  bool _detectAbnormalFrequency() {
    if (_blinkTimestamps.length < 3) return false;
    
    // Calcular frequência de piscadas por minuto
    int timeSpan = _blinkTimestamps.last - _blinkTimestamps.first;
    double minuteRatio = timeSpan / 60000.0; // converter para minutos
    
    if (minuteRatio <= 0) return false;
    
    double blinksPerMinute = _blinkTimestamps.length / minuteRatio;
    
    // Frequência normal é entre 10-20 piscadas por minuto
    // Frequência abaixo de 5 ou acima de 30 é suspeita
    if (blinksPerMinute < 5 || blinksPerMinute > 30) {
      return true;
    }
    
    return false;
  }
  
  double _calculateMedian(List<int> values) {
    if (values.isEmpty) return 0;
    
    List<int> sortedValues = List.from(values)..sort();
    int middle = sortedValues.length ~/ 2;
    
    if (sortedValues.length % 2 == 1) {
      return sortedValues[middle].toDouble();
    } else {
      return (sortedValues[middle - 1] + sortedValues[middle]) / 2.0;
    }
  }
  
  Map<String, dynamic> getAnalysisResults() {
    if (_blinkTimestamps.isEmpty) {
      return {
        'count': 0,
        'frequency': 0.0,
        'has_pattern': false
      };
    }
    
    int timeSpan = _blinkTimestamps.last - _blinkTimestamps.first;
    double minuteRatio = timeSpan > 0 ? timeSpan / 60000.0 : 0;
    double blinksPerMinute = minuteRatio > 0 ? _blinkTimestamps.length / minuteRatio : 0;
    
    return {
      'count': _blinkTimestamps.length,
      'frequency': blinksPerMinute,
      'has_pattern': detectAnomalyPatterns(),
      'time_window_seconds': _timeWindow / 1000
    };
  }
}