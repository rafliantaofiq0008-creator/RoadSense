import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../data/models/vibration_sample.dart';

class VibrationChart extends StatelessWidget {
  final List<VibrationSample> samples;

  const VibrationChart({super.key, required this.samples});

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No data yet.\nStart the sensor to see the chart.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Convert samples to FlSpot. We'll use the index for X axis to keep it simple and smooth.
    final spots = samples.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.vibration);
    }).toList();

    // Determine max Y value for scaling
    double maxY = 5.0;
    for (var sample in samples) {
      if (sample.vibration > maxY) {
        maxY = sample.vibration + 1.0;
      }
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        minX: 0,
        maxX: (samples.length > 50 ? samples.length.toDouble() : 50.0),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blueAccent.withValues(alpha: 0.1),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
            left: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
          ),
        ),
      ),
      duration: Duration.zero, // Disable animations to keep real-time updates smooth
    );
  }
}
