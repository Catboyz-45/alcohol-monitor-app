import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceStatus {
  final double bac;
  final int raw;
  final double threshold1;
  final double threshold2;
  final int alertLevel;

  const DeviceStatus({
    required this.bac,
    required this.raw,
    required this.threshold1,
    required this.threshold2,
    required this.alertLevel,
  });

  // แปลงค่า dynamic ให้เป็น double แบบปลอดภัย
  static double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  // แปลงค่า dynamic ให้เป็น int แบบปลอดภัย
  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  // แปลง payload shadow ให้เป็น DeviceStatus ที่พร้อมใช้งาน
  factory DeviceStatus.fromShadow(Map<String, dynamic> data) {
    final nested =
        data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : <String, dynamic>{};

    final source = nested.isNotEmpty ? nested : data;

    final t1 = _asDouble(source['threshold1'], fallback: 20.0);
    final t2 = _asDouble(source['threshold2'], fallback: 50.0);

    final raw = _asInt(source['raw']);
    // ใช้ค่า raw คำนวณ BAC สำรองเมื่อ payload ไม่มี bac โดยตรง
    final bacFromRaw = (raw / 4095.0) * 100.0;
    final bac = _asDouble(
      source['bac'] ?? source['alcohol'] ?? source['alcoholValue'],
      fallback: bacFromRaw,
    );

    return DeviceStatus(
      bac: bac,
      raw: raw,
      // สลับค่าให้แน่ใจว่า threshold1 <= threshold2 เสมอ
      threshold1: t1 <= t2 ? t1 : t2,
      threshold2: t1 <= t2 ? t2 : t1,
      alertLevel: _asInt(source['alertLevel']),
    );
  }
}

class HomeService {
  static const double bacMaxValue = 100.0;
  static const String controlUrl = String.fromEnvironment(
    'APP_NETPIE_CONTROL_URL',
    defaultValue:
        'https://api.netpie.io/v2/device/message?topic=home/device_control',
  );
  static const String statusUrl = String.fromEnvironment(
    'APP_NETPIE_STATUS_URL',
    defaultValue: 'https://api.netpie.io/v2/device/shadow/data',
  );
  static const String controlClientId = String.fromEnvironment(
    'APP_NETPIE_CONTROL_CLIENT_ID',
  );
  static const String controlToken = String.fromEnvironment(
    'APP_NETPIE_CONTROL_TOKEN',
  );
  static const String statusClientId = String.fromEnvironment(
    'APP_NETPIE_STATUS_CLIENT_ID',
  );
  static const String statusToken = String.fromEnvironment(
    'APP_NETPIE_STATUS_TOKEN',
  );

  static void _requireCredentials(String clientId, String token) {
    if (clientId.isEmpty || token.isEmpty) {
      throw StateError('NETPIE credentials are missing');
    }
  }

  // Header สำหรับคำสั่งควบคุมอุปกรณ์
  Map<String, String> get _controlHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Device $controlClientId:$controlToken',
  };

  // Header สำหรับอ่านสถานะจาก shadow
  Map<String, String> get _statusHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Device $statusClientId:$statusToken',
  };

  // ดึงสถานะอุปกรณ์ล่าสุดจาก NETPIE shadow
  Future<DeviceStatus> getDeviceStatus() async {
    _requireCredentials(statusClientId, statusToken);
    final response = await http.get(
      Uri.parse(statusUrl),
      headers: _statusHeaders,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final shadowData =
          data is Map<String, dynamic>
              ? (data['data'] is Map<String, dynamic>
                  ? data['data'] as Map<String, dynamic>
                  : data)
              : <String, dynamic>{};
      // แปลงข้อมูลที่ได้ให้เป็นโมเดลเดียวกันทั้งระบบ
      return DeviceStatus.fromShadow(shadowData);
    } else {
      throw Exception(
        'Failed to fetch device status (${response.statusCode}): ${response.body}',
      );
    }
  }

  // ส่งค่า threshold ทั้งสองไปยังอุปกรณ์
  Future<void> updateThresholds({
    required double threshold1,
    required double threshold2,
  }) async {
    _requireCredentials(controlClientId, controlToken);
    // คุมช่วงค่า BAC ให้อยู่ใน 0-100 เสมอ
    final normalizedT1 = threshold1.clamp(0.0, bacMaxValue);
    final normalizedT2 = threshold2.clamp(0.0, bacMaxValue);

    final low = normalizedT1 <= normalizedT2 ? normalizedT1 : normalizedT2;
    final high = normalizedT1 <= normalizedT2 ? normalizedT2 : normalizedT1;

    final payload = json.encode({'threshold1': low, 'threshold2': high});
    final response = await http.put(
      Uri.parse(controlUrl),
      headers: _controlHeaders,
      body: payload,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update thresholds');
    }
  }

  // ส่งคำสั่งเปิด/ปิดอุปกรณ์แบบ binary เช่น buzzer หรือ red LED
  Future<void> setBinaryControl({
    required String field,
    required bool isOn,
  }) async {
    _requireCredentials(controlClientId, controlToken);
    final payload = json.encode({field: isOn ? 1 : 0});
    final response = await http.put(
      Uri.parse(controlUrl),
      headers: _controlHeaders,
      body: payload,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send control command for $field');
    }
  }
}
