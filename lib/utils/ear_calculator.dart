import 'dart:math';

class EarCalculator {
  // Calcular a distância euclidiana entre dois pontos
  double _euclideanDistance(List<double> point1, List<double> point2) {
    return sqrt(pow(point1[0] - point2[0], 2) + pow(point1[1] - point2[1], 2));
  }
  
  // Calcular o Eye Aspect Ratio (EAR) baseado nos landmarks do olho
  // EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
  double calculateEAR(List<Map<String, dynamic>> detections) {
    if (detections.isEmpty) return 1.0; // Valor padrão quando não há detecção
    
    double totalEAR = 0.0;
    int validEyes = 0;
    
    for (var detection in detections) {
      if (detection.containsKey('landmarks')) {
        List<List<double>> landmarks = detection['landmarks'];
        
        // Verificar se temos pelo menos 6 pontos (necessários para o cálculo do EAR)
        if (landmarks.length >= 6) {
          // Baseado na fórmula do EAR:
          // EAR = (||p2-p6|| + ||p3-p5||) / (2 * ||p1-p4||)
          
          double d1 = _euclideanDistance(landmarks[1], landmarks[5]); // |p2-p6|
          double d2 = _euclideanDistance(landmarks[2], landmarks[4]); // |p3-p5|
          double d3 = _euclideanDistance(landmarks[0], landmarks[3]); // |p1-p4|
          
          if (d3 > 0) { // Evitar divisão por zero
            double ear = (d1 + d2) / (2.0 * d3);
            totalEAR += ear;
            validEyes++;
          }
        }
      }
    }
    
    // Retornar a média do EAR para todos os olhos detectados
    return validEyes > 0 ? totalEAR / validEyes : 1.0;
  }
}