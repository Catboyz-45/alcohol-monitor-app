import 'dart:async';
import 'dart:math' as math;

import 'app_state.dart';
import 'config.dart';
import 'device_reading.dart';
import 'mqtt_service.dart';

// ช่องทางคุยกับอุปกรณ์ (จริงหรือจำลอง)
abstract class DeviceLink {
  void start();
  void stop();
  Future<void> refresh();
  Future<void> sendThresholds(double threshold1, double threshold2);
}

// ต่ออุปกรณ์จริงผ่าน NETPIE MQTT อย่างเดียว
// บอร์ดส่ง heartbeat ทุก 5 วินาที จึงไม่ต้องอ่าน shadow ผ่าน REST
// (ซึ่งต้องใช้ token ของบอร์ดฝังไว้ในแอป)
class NetpieDeviceLink implements DeviceLink {
  NetpieDeviceLink(this.state);

  final AppState state;
  MqttService? _mqtt;
  Timer? _ticker;

  @override
  void start() {
    if (AppConfig.hasMqtt) {
      _mqtt = MqttService(
        clientId: AppConfig.mqttClientId,
        username: AppConfig.mqttUser,
        password: AppConfig.mqttPassword,
        onConnectionChanged: state.setMqttConnected,
        onReading: state.applyReading,
      )..connect();
    } else {
      state.setMqttConnected(false);
    }
    // อัปเดตป้าย "กี่วินาทีที่แล้ว" และตรวจว่าอุปกรณ์เงียบไปหรือยัง
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => state.tick());
  }

  @override
  void stop() {
    _ticker?.cancel();
    _mqtt?.disconnect();
  }

  // ขอสถานะล่าสุดจากบอร์ดทันที
  @override
  Future<void> refresh() async => _mqtt?.ping();

  @override
  Future<void> sendThresholds(double threshold1, double threshold2) async {
    final mqtt = _mqtt;
    if (mqtt == null) {
      throw StateError('ยังไม่ได้ตั้งค่า MQTT');
    }
    final payload = thresholdPayload(threshold1, threshold2);
    mqtt.sendThresholds(payload['threshold1']!, payload['threshold2']!);
    state.markThresholdsSent(payload['threshold1']!, payload['threshold2']!);
  }
}

// อุปกรณ์จำลองสำหรับโหมดสาธิต: ค่าพื้นหลังต่ำ เป่าเองเป็นระยะ หรือกดจำลองการเป่าได้
class SimulatedDeviceLink implements DeviceLink {
  SimulatedDeviceLink(this.state, {math.Random? random})
    : _random = random ?? math.Random();

  // ระยะห่างของการเป่าอัตโนมัติ (วินาที)
  static const int autoBlowEvery = 20;
  // ความยาวของการเป่าหนึ่งครั้ง (วินาที)
  static const int blowLength = 4;

  final AppState state;
  final math.Random _random;
  Timer? _timer;
  double _t1 = kDefaultThreshold1;
  double _t2 = kDefaultThreshold2;
  int _idleTicks = 0;
  int _blowStep = 0;
  double _blowPeak = 0;

  @override
  void start() {
    state.setMqttConnected(true);
    _emit();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
  }

  @override
  void stop() => _timer?.cancel();

  @override
  Future<void> refresh() async => _emit(advance: false);

  // เริ่มการเป่าจำลองทันที (ปุ่มในหน้าตรวจวัด)
  void triggerBlow() {
    _startBlow();
    _emit(advance: false);
  }

  // จำลองให้บอร์ดรับค่าแล้วส่งค่าใหม่กลับมา
  @override
  Future<void> sendThresholds(double threshold1, double threshold2) async {
    final payload = thresholdPayload(threshold1, threshold2);
    state.markThresholdsSent(payload['threshold1']!, payload['threshold2']!);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _t1 = payload['threshold1']!;
    _t2 = payload['threshold2']!;
    _emit(advance: false);
  }

  void _startBlow() {
    _blowStep = 1;
    _idleTicks = 0;
    _blowPeak = 12 + _random.nextDouble() * 60;
  }

  void _emit({bool advance = true}) {
    if (advance) {
      if (_blowStep > 0) {
        _blowStep = _blowStep >= blowLength ? 0 : _blowStep + 1;
      } else if (++_idleTicks >= autoBlowEvery) {
        _startBlow();
      }
    }

    final bac =
        _blowStep > 0
            ? _blowPeak * math.sin(_blowStep / (blowLength + 1) * math.pi)
            : 2 + _random.nextDouble() * 4;
    final rounded = (bac * 10).round() / 10;
    state.applyReading(
      DeviceReading(
        bac: rounded,
        raw: (rounded / kScaleMax * kAdcMax).round(),
        threshold1: _t1,
        threshold2: _t2,
        alertLevel: alertLevelFor(rounded, _t1, _t2),
      ),
    );
  }
}
