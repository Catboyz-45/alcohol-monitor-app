// โมเดลค่าที่อุปกรณ์ส่งมา ใช้ร่วมกันทั้ง MQTT และอุปกรณ์จำลอง
//
// ข้อตกลงกับ firmware (alcohol-monitor-firmware) ผ่าน NETPIE MQTT:
//   บอร์ด → แอป  @msg/home/device_status : {bac, raw, threshold1, threshold2, alertLevel, millis}
//                (ส่งเมื่อมีการเป่า, heartbeat ทุก 5 วินาที และตอบทันทีเมื่อได้ ping)
//   แอป → บอร์ด  @msg/home/device_control : {threshold1, threshold2} หรือ {ping: 1}

// ค่าต่ำสุด/สูงสุดของสเกลที่ firmware ใช้ (ADC 0-4095 แปลงเป็น 0-100)
const double kScaleMax = 100.0;
const int kAdcMax = 4095;
const double kDefaultThreshold1 = 20.0;
const double kDefaultThreshold2 = 50.0;

enum AlertStatus { safe, warning, danger }

extension AlertStatusCode on AlertStatus {
  // ค่าที่เก็บในฐานข้อมูล คงชื่อเดิมไว้เพื่อให้อ่านข้อมูลเก่าได้
  String get code => switch (this) {
    AlertStatus.safe => 'SAFE',
    AlertStatus.warning => 'WARNING',
    AlertStatus.danger => 'DRUNK',
  };

  String get label => switch (this) {
    AlertStatus.safe => 'ปลอดภัย',
    AlertStatus.warning => 'เฝ้าระวัง',
    AlertStatus.danger => 'เกินเกณฑ์',
  };

  static AlertStatus fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'WARNING':
        return AlertStatus.warning;
      case 'DRUNK':
      case 'DANGER':
        return AlertStatus.danger;
      default:
        return AlertStatus.safe;
    }
  }

  static AlertStatus fromLevel(int level) {
    if (level >= 2) {
      return AlertStatus.danger;
    }
    if (level == 1) {
      return AlertStatus.warning;
    }
    return AlertStatus.safe;
  }
}

// ใช้กติกาเดียวกับ updateAlertOutputs() ใน firmware
int alertLevelFor(double value, double threshold1, double threshold2) {
  if (value >= threshold2) {
    return 2;
  }
  if (value >= threshold1) {
    return 1;
  }
  return 0;
}

// คุมช่วงค่าให้อยู่ใน 0-100 และเรียง threshold1 <= threshold2 ก่อนส่งให้บอร์ด
Map<String, double> thresholdPayload(double t1, double t2) {
  final a = t1.clamp(0.0, kScaleMax).toDouble();
  final b = t2.clamp(0.0, kScaleMax).toDouble();
  return {'threshold1': a <= b ? a : b, 'threshold2': a <= b ? b : a};
}

class DeviceReading {
  final double bac;
  final int? raw;
  final double threshold1;
  final double threshold2;
  final int alertLevel;

  const DeviceReading({
    required this.bac,
    required this.threshold1,
    required this.threshold2,
    required this.alertLevel,
    this.raw,
  });

  AlertStatus get status => AlertStatusCode.fromLevel(alertLevel);

  // แปลง payload ของบอร์ด (รับแบบมี data ซ้อนแบบ shadow ได้ด้วย)
  // คืน null ถ้า payload ไม่มีค่าการวัดเลย
  static DeviceReading? tryParse(Object? decoded) {
    if (decoded is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(decoded);
    final source =
        map['data'] is Map
            ? Map<String, dynamic>.from(map['data'] as Map)
            : map;

    final raw = _asInt(source['raw']);
    final bacValue = _asDouble(source['bac']);
    final bac = bacValue ?? (raw == null ? null : raw / kAdcMax * kScaleMax);
    if (bac == null) {
      return null;
    }

    var t1 = _asDouble(source['threshold1']) ?? kDefaultThreshold1;
    var t2 = _asDouble(source['threshold2']) ?? kDefaultThreshold2;
    if (t1 > t2) {
      final temp = t1;
      t1 = t2;
      t2 = temp;
    }
    final clampedBac = bac.clamp(0.0, kScaleMax).toDouble();

    return DeviceReading(
      bac: clampedBac,
      raw: raw,
      threshold1: t1.clamp(0.0, kScaleMax).toDouble(),
      threshold2: t2.clamp(0.0, kScaleMax).toDouble(),
      alertLevel:
          _asInt(source['alertLevel']) ?? alertLevelFor(clampedBac, t1, t2),
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
