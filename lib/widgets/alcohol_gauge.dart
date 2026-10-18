import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../device_reading.dart';
import '../theme.dart';

// เกจครึ่งวงกลม แบ่งโซนปลอดภัย/เฝ้าระวัง/เกินเกณฑ์ตาม threshold
class AlcoholGauge extends StatelessWidget {
  const AlcoholGauge({
    super.key,
    required this.value,
    required this.threshold1,
    required this.threshold2,
  });

  final double value;
  final double threshold1;
  final double threshold2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'เกจค่าแอลกอฮอล์ ${value.toStringAsFixed(1)} จาก 100 '
          'เกณฑ์ ${threshold1.round()} และ ${threshold2.round()}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, 340.0);
          return Center(
            child: CustomPaint(
              size: Size(width, width * 0.58),
              painter: _GaugePainter(
                value: value.clamp(0.0, kScaleMax),
                threshold1: threshold1.clamp(0.0, kScaleMax),
                threshold2: threshold2.clamp(0.0, kScaleMax),
                track: scheme.surfaceContainerHighest,
                needle: scheme.onSurface,
                label: scheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.threshold1,
    required this.threshold2,
    required this.track,
    required this.needle,
    required this.label,
  });

  final double value;
  final double threshold1;
  final double threshold2;
  final Color track;
  final Color needle;
  final Color label;

  @override
  // วาดครึ่งวงกลม gauge พร้อม segment และเข็มชี้ค่า
  void paint(Canvas canvas, Size size) {
    const startAngle = math.pi;
    const sweepAngle = math.pi;
    const stroke = 18.0;
    final center = Offset(size.width / 2, size.height - 14);
    final radius = math.min(size.width / 2 - stroke, size.height - stroke - 6);
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    void segment(double from, double to, Color color) {
      final sweep = (to - from).clamp(0.0, kScaleMax) / kScaleMax * sweepAngle;
      if (sweep <= 0) {
        return;
      }
      canvas.drawArc(
        rect,
        startAngle + from / kScaleMax * sweepAngle,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
    }

    // วาดโซนปลอดภัย/เตือน/อันตรายตาม threshold
    segment(0, threshold1, AlertStatus.safe.color);
    segment(threshold1, threshold2, AlertStatus.warning.color);
    segment(threshold2, kScaleMax, AlertStatus.danger.color);

    // คำนวณปลายเข็มจากมุมตามค่า value ปัจจุบัน
    final angle = startAngle + value / kScaleMax * sweepAngle;
    final length = radius - stroke;
    final end = Offset(
      center.dx + length * math.cos(angle),
      center.dy + length * math.sin(angle),
    );
    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = needle
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 7, Paint()..color = needle);

    final style = TextStyle(color: label, fontSize: 12);
    _paintLabel(
      canvas,
      '0',
      Offset(center.dx - radius - 4, center.dy + 4),
      style,
    );
    _paintLabel(
      canvas,
      '100',
      Offset(center.dx + radius - 14, center.dy + 4),
      style,
    );
  }

  void _paintLabel(Canvas canvas, String text, Offset offset, TextStyle style) {
    TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) {
    return old.value != value ||
        old.threshold1 != threshold1 ||
        old.threshold2 != threshold2 ||
        old.track != track ||
        old.needle != needle;
  }
}
