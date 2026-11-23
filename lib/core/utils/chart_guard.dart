import 'package:flutter/material.dart';

class ChartSliceData {
  final String label;
  final double value;
  final Color color;

  const ChartSliceData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class SafeChartResult {
  final bool isEmpty;
  final double total;
  final List<ChartSliceData> slices;

  const SafeChartResult({
    required this.isEmpty,
    required this.total,
    required this.slices,
  });

  /// Returns 0% for all legend items whenever total <= 0 (never 100%).
  double percentageOf(double value) {
    if (isEmpty || total <= 0 || value <= 0) return 0.0;
    return (value / total) * 100.0;
  }

  String formattedPercent(double value) {
    return '${percentageOf(value).toStringAsFixed(0)}%';
  }
}

class ChartGuard {
  ChartGuard._();

  static SafeChartResult normalize(
      List<ChartSliceData> rawSlices, {
        Color emptyRingColor = const Color(0xFFE2E8F0),
      }) {
    final valid = rawSlices.where((s) => s.value > 0).toList();
    final total = valid.fold<double>(0.0, (sum, s) => sum + s.value);

    if (total <= 0) {
      return SafeChartResult(
        isEmpty: true,
        total: 0.0,
        slices: [
          ChartSliceData(label: 'No Data', value: 1.0, color: emptyRingColor),
        ],
      );
    }

    return SafeChartResult(isEmpty: false, total: total, slices: valid);
  }
}