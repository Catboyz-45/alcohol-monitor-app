import 'dart:async';
import 'dart:math' as math;

import 'app_state.dart';
import 'config.dart';
import 'device_reading.dart';
import 'home_service.dart';
import 'mqtt_service.dart';

// ช่องทางส่งค่า threshold ไปยังอุปกรณ์ (จริงหรือจำลอง)
abstract class DeviceLink {
  void start();
  void stop();
  Future<void> refresh();
  Future<void> sendThresholds(double threshold1, double threshold2);
}

// ต่ออุปกรณ์จริงผ่าน NETPIE: MQTT เป็นช่องทางหลัก, REST shadow เป็น heartbeat/สำรอง
class NetpieDeviceLink implements DeviceLink {
  NetpieDeviceLink(this.state, {HomeService? service})
    : _service = service ?? HomeService();

  final AppState state;
  final HomeService _service;
  MqttService? _mqtt;
  Timer? _pollTimer;
  Timer? _ticker;
  int? _lastShadowUptime;

  @override
  void start() {
    if (AppConfig.hasMqtt) {
      _mqtt = MqttService(
        clientId: AppConfig.mqttClientId,
        username: AppConfig.mqttUser,
        password: AppConfig.mqttPassword,
        onConnectionChanged: state.setMqttConnected,
        onReading: (reading) => state.applyReading(reading),
      )..connect();
    }
    if (AppConfig.hasNetpieStatus) {
      refresh();
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    } else if (!AppConfig.hasMqtt) {
      state.setRestOk(false);
    }
    // อัปเดตป้าย "กี่วินาทีที่แล้ว" และตรวจว่าอุปกรณ์เงียบไปหรือยัง
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => state.tick());
  }

  @override
  void stop() {
    _pollTimer?.cancel();
    _ticker?.cancel();
    _mqtt?.disconnect();
  }

  // อ่าน shadow: ถ้าค่า uptime ไม่เปลี่ยนแปลงแปลว่าบอร์ดไม่ได้อัปเดต (ค่าค้าง)
  @override
  Future<void> refresh() async {
    if (!AppConfig.hasNetpieStatus) {
      return;
    }
    try {
      final reading = await _service.getDeviceStatus();
      final uptime = reading.uptimeMs;
      final fresh =
          uptime == null
              // firmware รุ่นเก่าไม่มี uptime จึงตรวจความสดไม่ได้
              ? true
              : _lastShadowUptime != null && uptime != _lastShadowUptime;
      _lastShadowUptime = uptime;
      state.setRestOk(true);
      state.applyReading(reading, fresh: fresh);
    } catch (_) {
      state.setRestOk(false);
    }
  }

  @override
  Future<void> sendThresholds(double threshold1, double threshold2) async {
    final payload = HomeService.thresholdPayload(threshold1, threshold2);
    await _service.updateThresholds(
      threshold1: payload['threshold1']!,
      threshold2: payload['threshold2']!,
    );
    state.markThresholdsSent(payload['threshold1']!, payload['threshold2']!);
  }
}

// อุปกรณ์จำลองสำหรับโหมดสาธิต: ค่าพื้นหลังต่ำ และจำลองการเป่าเป็นระยะ
class SimulatedDeviceLink implements DeviceLink {
  SimulatedDeviceLink(this.state, {math.Random? random})
    : _random = random ?? math.Random();

  final AppState state;
  final math.Random _random;
  Timer? _timer;
  double _t1 = kDefaultThreshold1;
  double _t2 = kDefaultThreshold2;
  int _tick = 0;
  double _blowPeak = 0;
  int _uptimeMs = 0;

  @override
  void start() {
    state.setMqttConnected(true);
    state.setRestOk(true);
    _emit();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
  }

  @override
  void stop() => _timer?.cancel();

  @override
  Future<void> refresh() async => _emit();

  // จำลองให้บอร์ดรับค่าแล้วส่งค่าใหม่กลับมาในรอบถัดไป
  @override
  Future<void> sendThresholds(double threshold1, double threshold2) async {
    final payload = HomeService.thresholdPayload(threshold1, threshold2);
    state.markThresholdsSent(payload['threshold1']!, payload['threshold2']!);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _t1 = payload['threshold1']!;
    _t2 = payload['threshold2']!;
    _emit();
  }

  void _emit() {
    _tick++;
    _uptimeMs += 1000;
    // ทุก ~12 วินาทีจำลองการเป่า 1 ครั้ง ยาว 4 วินาที
    final phase = _tick % 12;
    if (phase == 1) {
      _blowPeak = 12 + _random.nextDouble() * 60;
    }
    final double bac;
    if (phase >= 1 && phase <= 4) {
      final shape = math.sin(phase / 5 * math.pi);
      bac = _blowPeak * shape;
    } else {
      bac = 2 + _random.nextDouble() * 4;
    }
    final rounded = (bac * 10).round() / 10;
    state.applyReading(
      DeviceReading(
        bac: rounded,
        raw: (rounded / kScaleMax * kAdcMax).round(),
        threshold1: _t1,
        threshold2: _t2,
        alertLevel: alertLevelFor(rounded, _t1, _t2),
        uptimeMs: _uptimeMs,
      ),
    );
  }
}
