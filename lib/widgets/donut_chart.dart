import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

@immutable
class DonutChartData {
  final double _value;
  final Color color;

  const DonutChartData({required double value, required this.color})
    : _value = value + 1;

  double get value => _value;

  @override
  String toString() {
    return 'DonutChartData{_value: $_value}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DonutChartData &&
          runtimeType == other.runtimeType &&
          _value == other._value &&
          color == other.color;

  @override
  int get hashCode => _value.hashCode ^ color.hashCode;
}

class DonutChart extends StatefulWidget {
  final List<DonutChartData> data;
  final Duration duration;

  const DonutChart({
    super.key,
    required this.data,
    this.duration = commonDuration,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<DonutChartData> _oldData;
  bool _hasAnimatedOnce = false;

  @override
  void initState() {
    super.initState();
    _oldData = widget.data;
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void didUpdateWidget(DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _oldData = oldWidget.data;
      if (!_hasAnimatedOnce ||
          _isSignificantChange(oldWidget.data, widget.data)) {
        _animationController.forward(from: 0);
        _hasAnimatedOnce = true;
      } else {
        _animationController.value = 1.0;
      }
    }
  }

  bool _isSignificantChange(
    List<DonutChartData> oldData,
    List<DonutChartData> newData,
  ) {
    if (oldData.length != newData.length) return true;
    for (var i = 0; i < oldData.length; i++) {
      final total = oldData[i].value + newData[i].value;
      if (total <= 0) continue;
      final diff = (newData[i].value - oldData[i].value).abs() / total;
      if (diff > 0.03) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return CustomPaint(
            painter: DonutChartPainter(
              _oldData,
              widget.data,
              _animationController.value,
            ),
          );
        },
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<DonutChartData> oldData;
  final List<DonutChartData> newData;
  final double progress;

  late final Paint _arcPaint;

  List<DonutChartData>? _cachedInterpolatedData;
  double? _cachedProgress;

  DonutChartPainter(this.oldData, this.newData, this.progress) {
    _arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
  }

  static const _logBase = 10.0;
  static const _minValue = 0.1;
  static final _logBaseInv = 1.0 / log(_logBase);

  double _logTransform(double value) {
    if (value < _minValue) return 0;
    return log(value) * _logBaseInv + 1;
  }

  double _expTransform(double value) {
    if (value <= 0) return 0;
    return pow(_logBase, value - 1).toDouble();
  }

  List<DonutChartData> get _interpolatedData {
    if (_cachedInterpolatedData != null && _cachedProgress == progress) {
      return _cachedInterpolatedData!;
    }

    if (newData.isEmpty) {
      _cachedInterpolatedData = newData;
      _cachedProgress = progress;
      return newData;
    }

    if (oldData.length != newData.length) {
      _cachedInterpolatedData = newData;
      _cachedProgress = progress;
      return newData;
    }

    final result = <DonutChartData>[];
    for (var i = 0; i < newData.length; i++) {
      final oldValue = oldData[i].value;
      final newValue = newData[i].value;
      final logOldValue = _logTransform(oldValue);
      final logNewValue = _logTransform(newValue);
      final interpolatedLogValue =
          logOldValue + (logNewValue - logOldValue) * progress;

      final interpolatedValue = _expTransform(interpolatedLogValue);

      result.add(
        DonutChartData(value: interpolatedValue, color: newData[i].color),
      );
    }

    _cachedInterpolatedData = result;
    _cachedProgress = progress;
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final data = _interpolatedData;
    if (data.isEmpty) return;

    double total = 0;
    for (final item in data) {
      total += item.value;
    }

    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 12.0;
    final radius = min(size.width / 2, size.height / 2) - strokeWidth / 2;

    final gapAngle = 2 * asin(strokeWidth * 1 / (2 * radius)) * 1.2;
    final availableAngle = 2 * pi - (data.length * gapAngle);
    final totalInv = 1.0 / total;

    double startAngle = -pi / 2 + gapAngle / 2;

    _arcPaint.strokeWidth = strokeWidth;

    for (final item in data) {
      final sweepAngle = availableAngle * (item.value * totalInv);

      if (sweepAngle <= 0) continue;

      _arcPaint.color = item.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        _arcPaint,
      );

      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.oldData != oldData ||
        oldDelegate.newData != newData;
  }
}
