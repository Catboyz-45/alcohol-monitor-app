import 'package:alcohol_monitor_app/device_reading.dart';
import 'package:alcohol_monitor_app/measurement_record.dart';
import 'package:alcohol_monitor_app/measurement_summary.dart';
import 'package:flutter_test/flutter_test.dart';

MeasurementRecord record({
  String id = 'r1',
  String name = 'สมชาย ใจดี',
  String idCard = '1101700203450',
  String licensePlate = '1กก 1234',
  String province = 'กรุงเทพมหานคร',
  double value = 25,
  String status = 'WARNING',
  DateTime? at,
}) => MeasurementRecord(
  id: id,
  name: name,
  idCard: idCard,
  age: 30,
  licensePlate: licensePlate,
  province: province,
  alcoholValue: value,
  status: status,
  timestamp: at ?? DateTime(2026, 11, 10, 14, 5),
);

void main() {
  group('DateRange', () {
    final now = DateTime(2026, 11, 10, 9, 30);

    test('วันนี้ นับตั้งแต่เที่ยงคืน ไม่ใช่ 24 ชั่วโมงย้อนหลัง', () {
      expect(DateRange.today.contains(DateTime(2026, 11, 10, 0, 0), now), true);
      expect(
        DateRange.today.contains(DateTime(2026, 11, 9, 23, 59), now),
        false,
      );
    });

    test('7 วัน คือวันนี้กับ 6 วันก่อนหน้า', () {
      expect(DateRange.last7Days.contains(DateTime(2026, 11, 4), now), true);
      expect(
        DateRange.last7Days.contains(DateTime(2026, 11, 3, 23, 59), now),
        false,
      );
    });

    test('30 วันข้ามเดือนได้', () {
      expect(DateRange.last30Days.contains(DateTime(2026, 10, 12), now), true);
      expect(
        DateRange.last30Days.contains(DateTime(2026, 10, 11, 23, 59), now),
        false,
      );
    });

    test('ทั้งหมด รวมข้อมูลเก่าที่ไม่มีวันที่ (epoch)', () {
      expect(
        DateRange.all.contains(DateTime.fromMillisecondsSinceEpoch(0), now),
        true,
      );
    });
  });

  group('MeasurementSummary', () {
    test('นับตามสถานะ ค่าเฉลี่ย และค่าสูงสุด', () {
      final summary = MeasurementSummary.of([
        record(value: 10, status: 'SAFE'),
        record(value: 30, status: 'WARNING'),
        record(value: 80, status: 'DRUNK'),
        record(value: 60, status: 'DRUNK'),
      ]);
      expect(summary.total, 4);
      expect(summary.count(AlertStatus.safe), 1);
      expect(summary.count(AlertStatus.warning), 1);
      expect(summary.count(AlertStatus.danger), 2);
      expect(summary.ratio(AlertStatus.danger), 0.5);
      expect(summary.average, 45);
      expect(summary.max, 80);
    });

    test('ไม่มีรายการ ไม่หารด้วยศูนย์', () {
      final summary = MeasurementSummary.of(const []);
      expect(summary.total, 0);
      expect(summary.average, isNull);
      expect(summary.max, isNull);
      expect(summary.ratio(AlertStatus.danger), 0);
    });
  });

  group('buildMeasurementsCsv', () {
    List<String> lines(String csv) => csv.split('\r\n');

    test('มี BOM หัวตาราง และใช้ CRLF', () {
      final csv = buildMeasurementsCsv([record()]);
      expect(csv.startsWith('﻿'), true);
      expect(lines(csv).first, '﻿${csvHeaders.join(',')}');
      expect(csv.endsWith('\r\n'), true);
      expect(lines(csv).where((l) => l.isNotEmpty).length, 2);
    });

    test('ข้อมูลหนึ่งแถวครบทุกคอลัมน์ และเลขบัตรถูกปิด', () {
      final row = lines(buildMeasurementsCsv([record()]))[1];
      expect(
        row,
        '2026-11-10,14:05,สมชาย ใจดี,X-XXXX-XXXXX-45-0,30,'
        '1กก 1234,กรุงเทพมหานคร,25.0,เฝ้าระวัง',
      );
      expect(row.contains('1101700203450'), false);
    });

    test('เลขบัตรที่เก็บแบบปิดไว้ในเครื่องก็ยังปิดอยู่', () {
      final row =
          lines(buildMeasurementsCsv([record(idCard: 'XXXXXXXXXX450')]))[1];
      expect(row.contains('X-XXXX-XXXXX-45-0'), true);
    });

    test('ครอบเครื่องหมายคำพูดเมื่อมี , หรือ "', () {
      final row =
          lines(buildMeasurementsCsv([record(name: 'สมชาย "ชาย", ใจดี')]))[1];
      expect(row.contains('"สมชาย ""ชาย"", ใจดี"'), true);
    });

    test('กันสูตร Excel ในช่องที่ผู้ใช้พิมพ์เอง', () {
      final row =
          lines(
            buildMeasurementsCsv([
              record(name: '=HYPERLINK("http://x")', licensePlate: '+1'),
            ]),
          )[1];
      expect(row.contains('"\'=HYPERLINK(""http://x"")"'), true);
      expect(row.contains(",'+1,"), true);
    });

    test('ไม่มีรายการ ได้แค่หัวตาราง', () {
      final csv = buildMeasurementsCsv(const []);
      expect(csv, '﻿${csvHeaders.join(',')}\r\n');
    });
  });

  test('ชื่อไฟล์มีวันเวลา', () {
    expect(
      csvFileName(DateTime(2026, 11, 10, 14, 5)),
      'alcohol-records-20261110-1405.csv',
    );
  });
}
