import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/yolo_service.dart';
import '../utils/ear_calculator.dart';
import '../models/blink_detection.dart';
import 'dart:async';
import 'dart:io';

class DetectionScreen extends StatefulWidget {
  @override
  _DetectionScreenState createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  late YoloService _yoloService;
  late EarCalculator _earCalculator;
  late BlinkDetector _blinkDetector;
  
  bool _isDetecting = false;
  bool _isCameraInitialized = false;
  List<Map<String, dynamic>> _detectionResults = [];
  List<Map<String, dynamic>> _blinkHistory = [];
  
  double _earValue = 0.0;
  int _blinkCount = 0;
  bool _showEyePoints = true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _initializeDetection();
  }
  
  void _initializeDetection() async {
    _yoloService = YoloService();
    await _yoloService.loadModel();
    
    _earCalculator = EarCalculator();
    _blinkDetector = BlinkDetector(
      earThreshold: 0.2,
      onBlinkDetected: (timestamp) {
        setState(() {
          _blinkCount++;
          _blinkHistory.add({
            'timestamp': timestamp,
            'duration': 0.3, // exemplo, em segundos
          });
        });
        
        // Analisar padrões de piscadas
        _analyzeBlinkPatterns();
      }
    );
  }
  
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.yuv420 
          : ImageFormatGroup.bgra8888,
    );
    
    await _cameraController!.initialize();
    
    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
      
      _startDetection();
    }
  }
  
  void _startDetection() {
    if (_cameraController != null) {
      _isDetecting = true;
      
      _cameraController!.startImageStream((CameraImage image) async {
        if (!_isDetecting) return;
        
        try {
          final results = await _yoloService.detectEyes(image);
          
          if (results.isNotEmpty) {
            // Calcular EAR se os olhos foram detectados
            final earValue = _earCalculator.calculateEAR(results);
            
            // Detectar piscadas
            _blinkDetector.processEAR(earValue, DateTime.now().millisecondsSinceEpoch);
            
            setState(() {
              _detectionResults = results;
              _earValue = earValue;
            });
          }
        } catch (e) {
          print('Error in detection: $e');
        }
      });
    }
  }
  
  void _stopDetection() {
    _isDetecting = false;
    _cameraController?.stopImageStream();
  }
  
  void _analyzeBlinkPatterns() {
    // Implementar lógica de análise de padrões aqui
    // Por exemplo, verificar sequências, ritmos ou frequências específicas
    
    if (_blinkHistory.length < 2) return;
    
    // Calcular intervalos entre piscadas
    List<int> intervals = [];
    for (int i = 1; i < _blinkHistory.length; i++) {
      int interval = _blinkHistory[i]['timestamp'] - _blinkHistory[i-1]['timestamp'];
      intervals.add(interval);
    }
    
    // Detectar padrões suspeitos
    // Exemplo simplificado: padrões rítmicos
    bool suspiciousPattern = _detectRhythmicPattern(intervals);
    
    if (suspiciousPattern) {
      // Atualizar UI para mostrar alerta
      print('Padrão suspeito detectado!');
    }
  }
  
  bool _detectRhythmicPattern(List<int> intervals) {
    // Exemplo simplificado de detecção de padrão
    if (intervals.length < 3) return false;
    
    // Verificar se há sequência de intervalos similares
    // (implementação simplificada para exemplo)
    int similarCount = 0;
    for (int i = 1; i < intervals.length; i++) {
      if ((intervals[i] - intervals[i-1]).abs() < 100) { // 100ms de tolerância
        similarCount++;
      }
    }
    
    return similarCount >= 2; // Pelo menos 3 intervalos similares
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    if (state == AppLifecycleState.inactive) {
      _stopDetection();
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopDetection();
    _cameraController?.dispose();
    _yoloService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'Deteksi Kedipan Mata',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A3990), Color(0xFF2A3990).withOpacity(0.7)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_showEyePoints ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showEyePoints = !_showEyePoints;
              });
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Camera preview
                Container(
                  width: double.infinity,
                  child: CameraPreview(_cameraController!),
                ),
                
                // Detection overlay
                if (_showEyePoints && _detectionResults.isNotEmpty)
                  CustomPaint(
                    size: Size(
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.width * _cameraController!.value.aspectRatio,
                    ),
                    painter: EyeDetectionPainter(
                      _detectionResults,
                      boxColor: Colors.green,
                      pointColor: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          
          // Detection results
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF2A3990),
            ),
            child: Column(
              children: [
                // EAR value and blink counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoCard(
                      'EAR Value',
                      _earValue.toStringAsFixed(3),
                      Icons.remove_red_eye,
                    ),
                    _buildInfoCard(
                      'Blink Count',
                      _blinkCount.toString(),
                      Icons.visibility_off,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                // Detection status
                Text(
                  _earValue < 0.2 ? 'Kedipan Terdeteksi!' : 'Monitoring...',
                  style: GoogleFonts.poppins(
                    color: _earValue < 0.2 ? Colors.red : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                
                // Pattern recognition status if enough blinks
                if (_blinkHistory.length > 3)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      _detectRhythmicPattern(_blinkHistory.map((b) => b['timestamp'] as int).toList().sublist(1))
                          ? 'Pola Mencurigakan Terdeteksi!'
                          : 'Tidak Ada Pola Mencurigakan',
                      style: GoogleFonts.poppins(
                        color: _detectRhythmicPattern(_blinkHistory.map((b) => b['timestamp'] as int).toList().sublist(1))
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          SizedBox(height: 5),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class EyeDetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Color boxColor;
  final Color pointColor;
  
  EyeDetectionPainter(this.detections, {required this.boxColor, required this.pointColor});
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint boxPaint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    final Paint pointPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;
    
    for (var detection in detections) {
      // Draw bounding box
      final Rect rect = Rect.fromLTRB(
        detection['rect'][0] * size.width,
        detection['rect'][1] * size.height,
        detection['rect'][2] * size.width,
        detection['rect'][3] * size.height,
      );
      canvas.drawRect(rect, boxPaint);
      
      // Draw eye landmarks
      if (detection.containsKey('landmarks')) {
        for (var landmark in detection['landmarks']) {
          final Offset point = Offset(
            landmark[0] * size.width,
            landmark[1] * size.height,
          );
          canvas.drawCircle(point, 2.0, pointPaint);
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(EyeDetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}