import 'device_reading.dart';
import 'measurement_record.dart';
import 'thai_id.dart';

// ช่วงเวลาที่ใช้กรองประวัติ สรุปผล และส่งออก
enum DateRange { today, last7Days, last30Days, all }

extension DateRangeLabel on DateRange {
  String get label => switch (this) {
    DateRange.today => 'วันนี้',
    DateRange.last7Days => '7 วัน',
    DateRange.last30Days => '30 วัน',
    DateRange.all => 'ทั้งหมด',
  };

  // ข้อความยาวสำหรับหัวการ์ดสรุป
  String get description => switch (this) {
    DateRange.today => 'วันนี้',
    DateRange.last7Days => '7 วันล่าสุด (รวมวันนี้)',
    DateRange.last30Days => '30 วันล่าสุด (รวมวันนี้)',
    DateRange.all => 'ทั้งหมด',
  };

  // นับตามวันในปฏิทินของเวลาเครื่อง: "7 วัน" คือวันนี้กับ 6 วันก่อนหน้า
  bool contains(DateTime time, DateTime now) {
    final days = switch (this) {
      DateRange.today => 1,
      DateRange.last7Days => 7,
      DateRange.last30Days => 30,
      DateRange.all => null,
    };
    if (days == null) {
      return true;
    }
    final localNow = now.toLocal();
    final start = DateTime(
      localNow.year,
      localNow.month,
      localNow.day - (days - 1),
    );
    return !time.toLocal().isBefore(start);
  }
}

// ตัวเลขสรุปของรายการชุดหนึ่ง
class MeasurementSummary {
  const MeasurementSummary._({
    required this.total,
    required this.counts,
    required this.average,
    required this.max,
  });

  factory MeasurementSummary.of(Iterable<MeasurementRecord> records) {
    final counts = {for (final s in AlertStatus.values) s: 0};
    var total = 0;
    var sum = 0.0;
    double? max;
    for (final r in records) {
      total++;
      counts[r.alertStatus] = counts[r.alertStatus]! + 1;
      sum += r.alcoholValue;
      if (max == null || r.alcoholValue > max) {
        max = r.alcoholValue;
      }
    }
    return MeasurementSummary._(
      total: total,
      counts: counts,
      average: total == 0 ? null : sum / total,
      max: max,
    );
  }

  final int total;
  final Map<AlertStatus, int> counts;

  // null เมื่อไม่มีรายการ
  final double? average;
  final double? max;

  int count(AlertStatus status) => counts[status] ?? 0;

  // สัดส่วน 0–1 ของสถานะนั้น
  double ratio(AlertStatus status) => total == 0 ? 0 : count(status) / total;
}

const csvHeaders = [
  'วันที่',
  'เวลา',
  'ชื่อ-นามสกุล',
  'เลขบัตรประชาชน (ปิดไว้)',
  'อายุ',
  'ทะเบียนรถ',
  'จังหวัด',
  'ค่าที่วัดได้ (สเกล 0-100)',
  'สถานะ',
];

// สร้าง CSV สำหรับเปิดใน Excel/Google Sheets
// - ขึ้นต้นด้วย BOM เพื่อให้ Excel อ่านภาษาไทยเป็น UTF-8
// - เลขบัตรประชาชนปิดไว้เสมอ ไฟล์ที่ส่งต่อกันจะไม่มีเลขเต็ม
// - กันสูตร Excel (CSV injection) ในช่องที่ผู้ใช้พิมพ์เอง
String buildMeasurementsCsv(Iterable<MeasurementRecord> records) {
  final buffer = StringBuffer('﻿');
  buffer.write(csvHeaders.map(_csvCell).join(','));
  buffer.write('\r\n');
  for (final r in records) {
    final t = r.timestamp.toLocal();
    final row = [
      '${t.year}-${_two(t.month)}-${_two(t.day)}',
      '${_two(t.hour)}:${_two(t.minute)}',
      _neutralizeFormula(r.name),
      maskThaiId(r.idCard),
      r.age.toString(),
      _neutralizeFormula(r.licensePlate),
      _neutralizeFormula(r.province),
      r.alcoholValue.toStringAsFixed(1),
      r.alertStatus.label,
    ];
    buffer.write(row.map(_csvCell).join(','));
    buffer.write('\r\n');
  }
  return buffer.toString();
}

// ชื่อไฟล์ เช่น alcohol-records-20261110-1405.csv
String csvFileName(DateTime now) {
  final t = now.toLocal();
  return 'alcohol-records-${t.year}${_two(t.month)}${_two(t.day)}'
      '-${_two(t.hour)}${_two(t.minute)}.csv';
}

String _two(int n) => n.toString().padLeft(2, '0');

String _csvCell(String value) {
  if (value.contains(RegExp(r'[",\r\n]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

// ค่าที่ขึ้นต้นด้วย = + - @ หรือ tab Excel จะตีความเป็นสูตร จึงเติม ' นำหน้า
String _neutralizeFormula(String value) {
  if (value.isNotEmpty && '=+-@\t\r'.contains(value[0])) {
    return "'$value";
  }
  return value;
}
