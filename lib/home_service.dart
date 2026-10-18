import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'device_reading.dart';

// เรียก NETPIE REST API: อ่าน shadow ของบอร์ด และส่งคำสั่งตั้ง threshold
class HomeService {
  HomeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static void _requireCredentials(String clientId, String token) {
    if (clientId.isEmpty || token.isEmpty) {
      throw StateError('NETPIE credentials are missing');
    }
  }

  Map<String, String> _headers(String clientId, String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Device $clientId:$token',
  };

  // ดึงสถานะอุปกรณ์ล่าสุดจาก NETPIE shadow
  Future<DeviceReading> getDeviceStatus() async {
    _requireCredentials(
      AppConfig.netpieStatusClientId,
      AppConfig.netpieStatusToken,
    );
    final response = await _client
        .get(
          Uri.parse(AppConfig.netpieStatusUrl),
          headers: _headers(
            AppConfig.netpieStatusClientId,
            AppConfig.netpieStatusToken,
          ),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('อ่าน shadow ไม่สำเร็จ (HTTP ${response.statusCode})');
    }
    final reading = DeviceReading.tryParse(
      json.decode(utf8.decode(response.bodyBytes)),
    );
    if (reading == null) {
      throw const FormatException('shadow ไม่มีค่าการวัด');
    }
    return reading;
  }

  // ส่งค่า threshold ทั้งสองไปยังอุปกรณ์ (topic @msg/home/device_control)
  Future<void> updateThresholds({
    required double threshold1,
    required double threshold2,
  }) async {
    _requireCredentials(
      AppConfig.netpieControlClientId,
      AppConfig.netpieControlToken,
    );
    final payload = json.encode(thresholdPayload(threshold1, threshold2));
    final response = await _client
        .put(
          Uri.parse(AppConfig.netpieControlUrl),
          headers: _headers(
            AppConfig.netpieControlClientId,
            AppConfig.netpieControlToken,
          ),
          body: payload,
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('ส่งค่าไม่สำเร็จ (HTTP ${response.statusCode})');
    }
  }

  // คุมช่วงค่าให้อยู่ใน 0-100 และเรียง threshold1 <= threshold2 ก่อนส่ง
  static Map<String, double> thresholdPayload(double t1, double t2) {
    final a = t1.clamp(0.0, kScaleMax).toDouble();
    final b = t2.clamp(0.0, kScaleMax).toDouble();
    return {'threshold1': a <= b ? a : b, 'threshold2': a <= b ? b : a};
  }
}
