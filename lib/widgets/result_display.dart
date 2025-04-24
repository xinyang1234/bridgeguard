import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../utils/timestamp_analyzer.dart';

class ResultDisplay extends StatelessWidget {
  final List<Map<String, dynamic>> blinkEvents;
  final bool isAnomalous;
  final TimestampAnalyzer _analyzer = TimestampAnalyzer();
  
  ResultDisplay({
    Key? key,
    required this.blinkEvents,
    required this.isAnomalous,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Analyze blink patterns
    final analysisResult = _analyzer.analyzeBlinkPattern(blinkEvents);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator
          _buildStatusIndicator(context, isAnomalous),
          const SizedBox(height: 16),
          
          // Statistics
          Expanded(
            child: blinkEvents.isEmpty
                ? _buildEmptyState(context)
                : _buildStatistics(context, analysisResult),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusIndicator(BuildContext context, bool isAnomalous) {
    final statusColor = isAnomalous
        ? AppConstants.dangerColor
        : blinkEvents.isEmpty
            ? AppConstants.warningColor
            : AppConstants.successColor;
            
    final statusText = isAnomalous
        ? 'Suspicious Pattern Detected'
        : blinkEvents.isEmpty
            ? 'Waiting for Data'
            : 'Normal Blinking Pattern';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAnomalous
                ? Icons.warning_amber_rounded
                : blinkEvents.isEmpty
                    ? Icons.hourglass_empty
                    : Icons.check_circle_outline,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.remove_red_eye_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No blink data yet',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start detection to analyze blinking patterns',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatistics(BuildContext context, Map<String, dynamic> analysis) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blink pattern type
          Text(
            'Pattern: ${analysis['pattern']}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Statistics cards
          Row(
            children: [
              _buildStatCard(
                context,
                '${analysis['count']}',
                'Total Blinks',
                Icons.visibility,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                context,
                '${analysis['rate'].toStringAsFixed(1)}',
                'Blinks/min',
                Icons.speed,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Recent blinks
          const Text(
            'Recent Blinks',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          SizedBox(
            height: 60,
            child: _buildBlinkTimeline(context),
          ),
          
          // Interpretations
          const SizedBox(height: 16),
          const Text(
            'Interpretations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getInterpretationText(analysis),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlinkTimeline(BuildContext context) {
    // Show at most the last 10 blinks
    final recentBlinks = blinkEvents.length > 10
        ? blinkEvents.sublist(blinkEvents.length - 10)
        : blinkEvents;
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: recentBlinks.length,
      itemBuilder: (context, index) {
        final blink = recentBlinks[index];
        final timestamp = DateTime.fromMillisecondsSinceEpoch(blink['timestamp']);
        final ear = blink['ear'] as double;
        
        return Container(
          margin: const EdgeInsets.only(right: 8),
          width: 40,
          child: Column(
            children: [
              Container(
                height: 25,
                width: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                child: Center(
                  child: Text(
                    ear.toStringAsFixed(2),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(4),
                                ),
                              ),
                              child: Text(
                                '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}.${timestamp.second.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
            ],
          ),
        );
      },
    );
  }
  
  String _getInterpretationText(Map<String, dynamic> analysis) {
    if (analysis['count'] == 0) {
      return 'No blinks detected yet. Normal blink rate is 15-20 per minute.';
    }
    
    final pattern = analysis['pattern'] as String;
    final rate = analysis['rate'] as double;
    final isSuspicious = analysis['suspicious'] as bool;
    
    if (isSuspicious) {
      switch (pattern) {
        case 'Rapid blinking':
          return 'Unusually high blink rate detected. This could indicate nervousness or an attempt to signal.';
        case 'Very infrequent blinking':
          return 'Unusually low blink rate detected. This could indicate high concentration or staring to signal.';
        case 'Rhythmic blinking':
          return 'Regular pattern of blinking detected. Potentially a signal system using timed blinks.';
        default:
          return 'Suspicious blinking pattern detected. Further analysis recommended.';
      }
    } else {
      if (rate < 10) {
        return 'Blink rate lower than average. This is common during focused activities like reading or using digital screens.';
      } else if (rate > 20) {
        return 'Blink rate higher than average. This can be normal during conversation or in dusty environments.';
      } else {
        return 'Blink rate within normal range (15-20 blinks per minute). No suspicious patterns detected.';
      }
    }
  }
}