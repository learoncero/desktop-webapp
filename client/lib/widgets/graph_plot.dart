import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LineChartGraph extends StatelessWidget {
  const LineChartGraph({
    super.key,
    required this.spots,
    required this.displayMax,
    required this.sensorUnit,
  });

  final List<FlSpot> spots;
  final int displayMax;
  final String? sensorUnit;

  Widget bottomTitleWidgets(double value, TitleMeta meta, double chartWidth) {
    if (value % 1 != 0) {
      return Container();
    }
    final style = TextStyle(fontSize: min(13, 18 * chartWidth / 300));
    return SideTitleWidget(
      meta: meta,
      space: 8,
      child: Transform.rotate(
        angle: 45 * pi / 180,
        alignment: Alignment.center,
        child: Text(meta.formattedValue, style: style),
      ),
    );
  }

  Widget leftTitleWidgets(double value, TitleMeta meta, double chartWidth) {
    final style = TextStyle(fontSize: min(13, 18 * chartWidth / 300));
    return SideTitleWidget(
      meta: meta,
      space: 16,
      child: Text(meta.formattedValue, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double minYValue = spots.isEmpty
        ? 0
        : spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    final double maxYValue = spots.isEmpty
        ? 1
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    const double padding = 0.2;

    final double minY = minYValue - padding;
    final double maxY = maxYValue + padding;

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12, right: 20, top: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  maxContentWidth: 100,
                  getTooltipColor: (touchedSpot) =>
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      final textStyle = TextStyle(
                        color:
                            touchedSpot.bar.gradient?.colors[0] ??
                            touchedSpot.bar.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      );
                      return LineTooltipItem(
                        '${touchedSpot.x.toInt()}s, ${touchedSpot.y.toStringAsFixed(2)} $sensorUnit',
                        textStyle,
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
                getTouchLineStart: (data, index) => 0,
              ),
              lineBarsData: [
                LineChartBarData(
                  color: Theme.of(context).colorScheme.primary,
                  spots: spots,
                  isCurved: true,
                  isStrokeCapRound: true,
                  barWidth: 3,
                  belowBarData: BarAreaData(show: false),
                  dotData: const FlDotData(show: false),
                ),
              ],
              minY: minY,
              maxY: maxY,
              maxX: displayMax.toDouble(),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) =>
                        leftTitleWidgets(value, meta, constraints.maxWidth),
                    reservedSize: 56,
                  ),
                  drawBelowEverything: true,
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) =>
                        bottomTitleWidgets(value, meta, constraints.maxWidth),
                    reservedSize: 36,
                    interval: 1,
                  ),
                  drawBelowEverything: true,
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                drawVerticalLine: true,
                horizontalInterval: 1,
                verticalInterval: 1,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  dashArray: [5, 5],
                  strokeWidth: 0.8,
                ),
                getDrawingVerticalLine: (_) => FlLine(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  dashArray: [5, 5],
                  strokeWidth: 0.8,
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          );
        },
      ),
    );
  }
}
