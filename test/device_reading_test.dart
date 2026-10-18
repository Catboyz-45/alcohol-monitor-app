import 'package:alcohol_monitor_app/device_reading.dart';
import 'package:alcohol_monitor_app/home_service.dart';
import 'package:alcohol_monitor_app/mqtt_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceReading.tryParse', () {
    test('อ่าน payload MQTT ของ firmware ได้ครบทุก field', () {
      final reading =
          MqttService.parsePayload(
            '{"bac":32.5,"raw":1331,"threshold1":20,"threshold2":50,'
            '"alertLevel":1,"millis":120000}',
          )!;

      expect(reading.bac, 32.5);
      expect(reading.raw, 1331);
      expect(reading.threshold1, 20);
      expect(reading.threshold2, 50);
      expect(reading.alertLevel, 1);
      expect(reading.status, AlertStatus.warning);
      expect(reading.uptimeMs, 120000);
    });

    test('shadow แบบมี data ซ้อน และไม่มี alertLevel จะคำนวณระดับเอง', () {
      // รูปแบบ shadow ของ firmware รุ่นเดิม (ไม่มี alertLevel/raw)
      final reading =
          DeviceReading.tryParse({
            'deviceid': 'abc',
            'data': {
              'red': 1,
              'yellow': 1,
              'led1': 1,
              'bac': 55.0,
              'threshold1': 20,
              'threshold2': 50,
            },
          })!;

      expect(reading.alertLevel, 2);
      expect(reading.status, AlertStatus.danger);
      expect(reading.raw, isNull);
      expect(reading.uptimeMs, isNull);
    });

    test('อ่าน uptime จาก shadow รุ่นใหม่', () {
      final reading =
          DeviceReading.tryParse({
            'data': {'bac': 3, 'uptime': 5000, 'alertLevel': 0, 'raw': 120},
          })!;
      expect(reading.uptimeMs, 5000);
      expect(reading.raw, 120);
    });

    test('ไม่มี bac แต่มี raw จะแปลงด้วยสูตรเดียวกับ firmware', () {
      final reading = DeviceReading.tryParse({'raw': 4095})!;
      expect(reading.bac, 100);
      expect(reading.threshold1, kDefaultThreshold1);
      expect(reading.threshold2, kDefaultThreshold2);
    });

    test('รับตัวเลขที่เป็น string และสลับ threshold ที่กลับด้าน', () {
      final reading =
          DeviceReading.tryParse({
            'bac': '12.5',
            'threshold1': '60',
            'threshold2': '30',
          })!;
      expect(reading.bac, 12.5);
      expect(reading.threshold1, 30);
      expect(reading.threshold2, 60);
    });

    test('คุมค่าให้อยู่ในช่วง 0-100', () {
      final reading = DeviceReading.tryParse({'bac': 140, 'threshold2': 150})!;
      expect(reading.bac, 100);
      expect(reading.threshold2, 100);
    });

    test('payload ที่ไม่มีค่าการวัด หรือ JSON เสีย คืน null', () {
      expect(
        DeviceReading.tryParse({
          'data': {'red': 1},
        }),
        isNull,
      );
      expect(DeviceReading.tryParse('not a map'), isNull);
      expect(MqttService.parsePayload('{oops'), isNull);
      expect(MqttService.parsePayload('[1,2]'), isNull);
    });
  });

  group('alertLevelFor', () {
    test('ใช้ >= เหมือน updateAlertOutputs() ใน firmware', () {
      expect(alertLevelFor(19.9, 20, 50), 0);
      expect(alertLevelFor(20, 20, 50), 1);
      expect(alertLevelFor(49.9, 20, 50), 1);
      expect(alertLevelFor(50, 20, 50), 2);
    });
  });

  group('AlertStatus', () {
    test('แปลง code เก่าในฐานข้อมูลได้', () {
      expect(AlertStatusCode.fromCode('SAFE'), AlertStatus.safe);
      expect(AlertStatusCode.fromCode('sober'), AlertStatus.safe);
      expect(AlertStatusCode.fromCode('WARNING'), AlertStatus.warning);
      expect(AlertStatusCode.fromCode('DRUNK'), AlertStatus.danger);
      expect(AlertStatus.danger.code, 'DRUNK');
    });
  });

  group('HomeService', () {
    test('thresholdPayload เรียงค่าและคุมช่วงก่อนส่งให้บอร์ด', () {
      expect(HomeService.thresholdPayload(70, 30), {
        'threshold1': 30.0,
        'threshold2': 70.0,
      });
      expect(HomeService.thresholdPayload(-5, 120), {
        'threshold1': 0.0,
        'threshold2': 100.0,
      });
    });

    test('ไม่ได้ตั้งค่า NETPIE จะไม่ยิง request', () {
      expect(HomeService().getDeviceStatus(), throwsStateError);
      expect(
        HomeService().updateThresholds(threshold1: 1, threshold2: 2),
        throwsStateError,
      );
    });
  });
}
