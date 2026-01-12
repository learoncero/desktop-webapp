import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LineChartGraph extends StatelessWidget {
  const LineChartGraph({
    super.key,
    required this.spots,
    required this.displayMax,
    required this.sensorUnit,
    required this.visibleRange,
  });

  final List<FlSpot> spots;
  final int displayMax;
  final String? sensorUnit;
  final int visibleRange;

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
      child: Text(_formatYTextValue(value), style: style),
    );
  }

  String _formatYTextValue(double value) {
    if (value.abs() >= 1000) {
      return value.toStringAsFixed(0);
    } else if (value.abs() >= 100) {
      return value.toStringAsFixed(1);
    } else {
      return value.toStringAsFixed(2);
    }
  }

  double _calculateIntervalX() {
    if (visibleRange <= 10) return 1.0;
    if (visibleRange <= 30) return 2.0;
    if (visibleRange <= 60) return 5.0;
    if (visibleRange <= 120) return 10.0;
    if (visibleRange <= 180) return 20.0;
    return 20.0; // For 180+ seconds, use 1 minute intervals
  }

  double _calculateIntervalY(double minY, double maxY) {
    final range = maxY - minY;

    if (range == 0) {
      return 1;
    }

    // based on range, set amount of horizontal lines
    int lines = 8;
    if (range < 1) {
      lines = 1;
    } else if (range < 2.5) {
      lines = 2;
    } else if (range < 5) {
      lines = 4;
    } else if (range < 10) {
      lines = 6;
    }

    final rawInterval = range / lines;
    final exponent = pow(10, (log(rawInterval) / ln10).floor());
    final fraction = rawInterval / exponent;

    double fractionInterval;
    if (fraction < 1.5) {
      fractionInterval = 1;
    } else if (fraction < 3) {
      fractionInterval = 2;
    } else if (fraction < 7) {
      fractionInterval = 5;
    } else {
      fractionInterval = 10;
    }

    return fractionInterval * exponent;
  }

  @override
  Widget build(BuildContext context) {
    final double minYValue = spots.isEmpty
        ? 0
        : spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    final double maxYValue = spots.isEmpty
        ? 1
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    final intervalX = _calculateIntervalX();

    final intervalY = _calculateIntervalY(minYValue, maxYValue);
    final double minY = (minYValue / intervalY).floor() * intervalY;
    final double maxY = (maxYValue / intervalY).ceil() * intervalY;

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12, right: 20, top: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
            return const SizedBox.shrink();
          }
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
                        '${touchedSpot.x.toInt()}s, ${touchedSpot.y.toStringAsFixed(2)}$sensorUnit',
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
                    interval: intervalY,
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
                    interval: intervalX,
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
                verticalInterval: intervalX,
                horizontalInterval: intervalY,
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
