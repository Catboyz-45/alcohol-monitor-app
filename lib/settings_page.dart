import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.onSendThreshold,
    required this.onSetBuzzer,
    required this.onSetLed,
    required this.onReconnect,
  });

  final VoidCallback onSendThreshold;
  final void Function(bool) onSetBuzzer;
  final void Function(bool) onSetLed;
  final VoidCallback onReconnect;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _localThreshold1 = 20;
  int _localThreshold2 = 50;
  // true = ผู้ใช้แก้ค่าแล้วแต่ยังไม่ได้กดส่ง → ไม่ sync จาก AppState
  bool _pendingEdit = false;

  @override
  // โหลดค่า threshold ปัจจุบันจาก AppState มาเป็นค่าแก้ไขในหน้า settings
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final appState = Provider.of<AppState>(context, listen: false);
      setState(() {
        _localThreshold1 = appState.threshold;
        _localThreshold2 = appState.threshold2;
      });
    });
  }

  @override
  // สร้างหน้า settings ทั้งส่วน MQTT, threshold และ gauge
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // sync ค่าจาก AppState ทุกครั้งที่ polling อัปเดต ถ้าผู้ใช้ยังไม่ได้แตะ slider
        if (!_pendingEdit) {
          _localThreshold1 = appState.threshold;
          _localThreshold2 = appState.threshold2;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'การตั้งค่า',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'สถานะ MQTT',
                      style: GoogleFonts.poppins(fontSize: 18),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                appState.connected ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            appState.connected
                                ? 'เชื่อมต่อแล้ว'
                                : 'ไม่ได้เชื่อมต่อ',
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: widget.onReconnect,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'เชื่อมต่อใหม่',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ค่ามาตรฐานเตือนแอลกอฮอล์',
                      style: GoogleFonts.poppins(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'กาหนดค่าเกณฑ์ที่จะแจ้งเตือนเมื่อตรวจพบแอลกอฮอล์',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Threshold 1: $_localThreshold1',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    Slider(
                      min: 1,
                      max: 100,
                      divisions: 99,
                      value: _localThreshold1.toDouble().clamp(1, 100),
                      label: _localThreshold1.toString(),
                      onChanged: (value) {
                        setState(() {
                          _pendingEdit = true;
                          _localThreshold1 = value.toInt();
                          // บังคับลำดับให้ threshold1 <= threshold2
                          if (_localThreshold1 > _localThreshold2) {
                            _localThreshold2 = _localThreshold1;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Threshold 2: $_localThreshold2',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    Slider(
                      min: 1,
                      max: 100,
                      divisions: 99,
                      value: _localThreshold2.toDouble().clamp(1, 100),
                      label: _localThreshold2.toString(),
                      onChanged: (value) {
                        setState(() {
                          _pendingEdit = true;
                          _localThreshold2 = value.toInt();
                          // บังคับลำดับให้ threshold1 <= threshold2
                          if (_localThreshold2 < _localThreshold1) {
                            _localThreshold1 = _localThreshold2;
                          }
                        });
                      },
                    ),
                    Row(
                      children: [
                        Text(
                          '$_localThreshold1 / $_localThreshold2',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            // อัปเดตค่าใน AppState ก่อนส่งขึ้นอุปกรณ์
                            appState.updateThreshold(_localThreshold1);
                            appState.updateThreshold2(_localThreshold2);
                            setState(() => _pendingEdit = false);
                            widget.onSendThreshold();
                          },
                          icon: const Icon(Icons.send),
                          label: const Text('ส่งค่ามาตรฐาน'),
                          style: ElevatedButton.styleFrom(
                            // การ์ดพื้นฐานของหน้านี้ ใช้ซ้ำทุก section
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alcohol Panel',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Current BAC',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (appState.latestBoardAlcohol ?? appState.alcohol)
                          .clamp(0.0, 100.0)
                          .toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'BAC',
                      style: TextStyle(fontSize: 18, color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 220,
                      child: _buildGaugePanel(
                        bacValue:
                            appState.latestBoardAlcohol ?? appState.alcohol,
                        threshold1: appState.threshold.toDouble(),
                        threshold2: appState.threshold2.toDouble(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildLegendItem('Threshold 1', Colors.greenAccent),
                        _buildLegendItem('Threshold 2', Colors.amberAccent),
                        _buildLegendItem('Danger', Colors.redAccent),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      appState.lastUpdate == null
                          ? 'อัปเดตล่าสุด: -'
                          : 'อัปเดตล่าสุด: ${_formatDateTime(appState.lastUpdate!)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  // สร้าง panel gauge โดย normalize ค่าและปรับขนาดตามพื้นที่
  Widget _buildGaugePanel({
    required double bacValue,
    required double threshold1,
    required double threshold2,
  }) {
    // คุมค่าให้อยู่ช่วง 0-100 ก่อนวาด
    final normalizedValue = bacValue.clamp(0.0, 100.0);
    final normalizedThreshold1 = threshold1.clamp(0.0, 100.0);
    final normalizedThreshold2 = threshold2.clamp(0.0, 100.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // จำกัดความกว้างสูงสุดเพื่อคงสัดส่วน gauge
        final gaugeWidth = math.min(constraints.maxWidth, 360.0);
        final gaugeHeight = gaugeWidth * 0.62;

        return Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: CustomPaint(
                size: Size(gaugeWidth, gaugeHeight),
                painter: _GaugePainter(
                  value: normalizedValue,
                  threshold1: normalizedThreshold1,
                  threshold2: normalizedThreshold2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // แสดง legend สีของแต่ละช่วงค่า
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  // ฟอร์แมตวันที่ภาษาไทยแบบอ่านง่าย
  String _formatDateTime(DateTime dateTime) {
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];

    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} '
        'เวลา ${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.threshold1,
    required this.threshold2,
  });

  final double value;
  final double threshold1;
  final double threshold2;

  @override
  // วาดครึ่งวงกลม gauge พร้อม segment และเข็มชี้ค่า BAC
  void paint(Canvas canvas, Size size) {
    const startAngle = math.pi;
    const sweepAngle = math.pi;
    final center = Offset(size.width / 2, size.height - 8);
    final radius = math.min(size.width / 2 - 12, size.height - 12);

    final trackPaint =
        Paint()
          ..color = Colors.white12
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // วาดโซนปลอดภัย/เตือน/อันตรายตาม threshold
    _drawSegment(
      canvas,
      center,
      radius,
      startAngle,
      threshold1 / 100 * sweepAngle,
      Colors.greenAccent,
    );
    _drawSegment(
      canvas,
      center,
      radius,
      startAngle + threshold1 / 100 * sweepAngle,
      (threshold2 - threshold1).clamp(0.0, 100.0) / 100 * sweepAngle,
      Colors.amberAccent,
    );
    _drawSegment(
      canvas,
      center,
      radius,
      startAngle + threshold2 / 100 * sweepAngle,
      (100 - threshold2).clamp(0.0, 100.0) / 100 * sweepAngle,
      Colors.redAccent,
    );

    // คำนวณปลายเข็มจากมุมตามค่า value ปัจจุบัน
    final needleAngle = startAngle + (value / 100 * sweepAngle);
    final needleLength = radius - 18;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );

    final needlePaint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);

    final labelStyle = const TextStyle(color: Colors.white60, fontSize: 14);
    _paintLabel(canvas, '0', Offset(18, size.height - 6), labelStyle);
    _paintLabel(
      canvas,
      '100',
      Offset(size.width - 52, size.height - 6),
      labelStyle,
    );
  }

  // วาด arc segment ทีละช่วงของ gauge
  void _drawSegment(
    Canvas canvas,
    Offset center,
    double radius,
    double start,
    double sweep,
    Color color,
  ) {
    if (sweep <= 0) {
      return;
    }

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      paint,
    );
  }

  // วาดตัวเลขปลายสเกลบน gauge
  void _paintLabel(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  // วาดใหม่เฉพาะเมื่อค่าหลักเปลี่ยน ช่วยลดงาน render
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.threshold1 != threshold1 ||
        oldDelegate.threshold2 != threshold2;
  }
}
