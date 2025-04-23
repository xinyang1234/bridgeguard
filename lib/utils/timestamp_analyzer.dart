class TimestampAnalyzer {
  // Threshold untuk padrões suspeitos de comunicação
  static const double PATTERN_SIMILARITY_THRESHOLD = 0.2; // 20% de tolerância
  static const int MIN_SEQUENCE_LENGTH = 3; // Comprimento mínimo de sequência para considerar um padrão
  
  // Detectar padrões rítmicos nos timestamps
  static bool detectRhythmicPattern(List<int> timestamps) {
    if (timestamps.length < MIN_SEQUENCE_LENGTH + 1) {
      return false;
    }
    
    // Calcular intervalos entre timestamps
    List<int> intervals = [];
    for (int i = 1; i < timestamps.length; i++) {
      intervals.add(timestamps[i] - timestamps[i-1]);
    }
    
    // Verificar padrões rítmicos
    return _checkConsistentIntervals(intervals) || 
           _checkAlternatingPattern(intervals) ||
           _checkMorseCodeLikePattern(intervals);
  }
  
  // Verificar se há uma sequência consistente de intervalos similares
  static bool _checkConsistentIntervals(List<int> intervals) {
    if (intervals.length < MIN_SEQUENCE_LENGTH) return false;
    
    int consistentCount = 1;
    double averageInterval = intervals[0].toDouble();
    
    for (int i = 1; i < intervals.length; i++) {
      double variation = (intervals[i] - averageInterval).abs() / averageInterval;
      
      if (variation <= PATTERN_SIMILARITY_THRESHOLD) {
        consistentCount++;
        // Atualizar média para maior precisão
        averageInterval = (averageInterval * consistentCount + intervals[i]) / (consistentCount + 1);
      } else {
        consistentCount = 1;
        averageInterval = intervals[i].toDouble();
      }
      
      if (consistentCount >= MIN_SEQUENCE_LENGTH) {
        return true;
      }
    }
    
    return false;
  }
  
  // Verificar padrões alternados (curto-longo-curto-longo)
  static bool _checkAlternatingPattern(List<int> intervals) {
    if (intervals.length < MIN_SEQUENCE_LENGTH + 1) return false;
    
    List<double> ratios = [];
    for (int i = 1; i < intervals.length; i++) {
      ratios.add(intervals[i] / intervals[i-1]);
    }
    
    // Identificar padrões como alternância entre curto e longo
    int consistentAlternations = 1;
    for (int i = 1; i < ratios.length; i++) {
      // Para alternância, esperamos que ratio[i] ~= 1/ratio[i-1]
      double expectedRatio = 1 / ratios[i-1];
      double variation = (ratios[i] - expectedRatio).abs() / expectedRatio;
      
      if (variation <= PATTERN_SIMILARITY_THRESHOLD * 2) { // Tolerância um pouco maior
        consistentAlternations++;
      } else {
        consistentAlternations = 1;
      }
      
      if (consistentAlternations >= MIN_SEQUENCE_LENGTH - 1) {
        return true;
      }
    }
    
    return false;
  }
  
  // Detectar padrões semelhantes ao código Morse
  static bool _checkMorseCodeLikePattern(List<int> intervals) {
    if (intervals.length < 5) return false; // Precisa de mais pontos para detectar Morse
    
    // Separar intervalos em grupos (curtos e longos)
    Map<String, List<int>> groups = _groupIntervals(intervals);
    
    // Se encontrarmos dois grupos claros (curto e longo)
    if (groups.length == 2) {
      List<String> pattern = _convertToPattern(intervals, groups);
      
      // Verificar por sequências repetitivas no padrão
      return _checkRepeatedSubsequence(pattern);
    }
    
    return false;
  }
  
  // Agrupar intervalos similares (para detecção de Morse)
  static Map<String, List<int>> _groupIntervals(List<int> intervals) {
    Map<String, List<int>> groups = {};
    
    for (int interval in intervals) {
      bool grouped = false;
      
      for (String groupKey in groups.keys) {
        int groupAvg = groups[groupKey]!.reduce((a, b) => a + b) ~/ groups[groupKey]!.length;
        double variation = (interval - groupAvg).abs() / groupAvg;
        
        if (variation <= PATTERN_SIMILARITY_THRESHOLD) {
          groups[groupKey]!.add(interval);
          grouped = true;
          break;
        }
      }
      
      if (!grouped) {
        // Criar novo grupo
        groups['group_${groups.length}'] = [interval];
      }
    }
    
    return groups;
  }
  
  // Converter intervalos em padrão (ex: "SLLSLS" para curto-longo-longo-curto...)
  static List<String> _convertToPattern(List<int> intervals, Map<String, List<int>> groups) {
    List<String> keys = groups.keys.toList();
    int avg1 = groups[keys[0]]!.reduce((a, b) => a + b) ~/ groups[keys[0]]!.length;
    int avg2 = groups[keys[1]]!.reduce((a, b) => a + b) ~/ groups[keys[1]]!.length;
    
    String shortKey = avg1 < avg2 ? keys[0] : keys[1];
    String longKey = avg1 < avg2 ? keys[1] : keys[0];
    
    List<String> pattern = [];
    for (int interval in intervals) {
      int avg1 = groups[keys[0]]!.reduce((a, b) => a + b) ~/ groups[keys[0]]!.length;
      double variation1 = (interval - avg1).abs() / avg1;
      
      int avg2 = groups[keys[1]]!.reduce((a, b) => a + b) ~/ groups[keys[1]]!.length;
      double variation2 = (interval - avg2).abs() / avg2;
      
      if (variation1 <= variation2) {
        pattern.add(keys[0] == shortKey ? 'S' : 'L');
      } else {
        pattern.add(keys[1] == shortKey ? 'S' : 'L');
      }
    }
    
    return pattern;
  }
  
  // Verificar por subsequências repetidas
  static bool _checkRepeatedSubsequence(List<String> pattern) {
    if (pattern.length < 6) return false;
    
    // Procurar por subsequências de 2-4 elementos que se repetem
    for (int length = 2; length <= 4; length++) {
      if (pattern.length < length * 2) continue;
      
      for (int i = 0; i <= pattern.length - length * 2; i++) {
        List<String> subseq = pattern.sublist(i, i + length);
        
        // Procurar por repetições desta subsequência
        int matches = 0;
        for (int j = i + length; j <= pattern.length - length; j += length) {
          bool isMatch = true;
          for (int k = 0; k < length; k++) {
            if (pattern[j + k] != subseq[k]) {
              isMatch = false;
              break;
            }
          }
          
          if (isMatch) {
            matches++;
            if (matches >= 1) { // Encontrada pelo menos uma repetição
              return true;
            }
          } else {
            // Se não for match, pular para o próximo índice após este
            break;
          }
        }
      }
    }
    
    return false;
  }
}