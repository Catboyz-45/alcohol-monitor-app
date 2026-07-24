import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_client_factory.dart';

class MqttShadowUpdate {
  final double bac;
  final int raw;
  final double threshold1;
  final double threshold2;
  final int alertLevel;

  const MqttShadowUpdate({
    required this.bac,
    required this.raw,
    required this.threshold1,
    required this.threshold2,
    required this.alertLevel,
  });
}

class MqttService {
  static const String _defaultHost = String.fromEnvironment(
    'APP_MQTT_HOST',
    defaultValue: 'mqtt.netpie.io',
  );
  static const String _defaultWsUrl = String.fromEnvironment(
    'APP_MQTT_WS_URL',
    defaultValue: 'wss://mqtt.netpie.io:443/mqtt',
  );

  final String clientId;
  final String username;
  final String password;
  final void Function(MqttShadowUpdate) onShadowUpdate;
  final void Function(bool) onConnectionChanged;

  late MqttClient _client;

  MqttService({
    required this.clientId,
    required this.username,
    required this.password,
    required this.onShadowUpdate,
    required this.onConnectionChanged,
  });

  // แปลงค่า dynamic เป็น double แบบปลอดภัย
  static double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  // แปลงค่า dynamic เป็น int แบบปลอดภัย
  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  // เชื่อมต่อ broker และ subscribe topic ที่ต้องใช้
  Future<void> connect() async {
    _client = createMqttClient(
      clientId: clientId,
      host: _defaultHost,
      wsUrl: _defaultWsUrl,
    );

    _client.keepAlivePeriod = 20;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;

    _client.connectionMessage =
        MqttConnectMessage()
            .withClientIdentifier(clientId)
            .authenticateAs(username, password)
            .startClean();

    try {
      await _client.connect();
    } catch (_) {
      // ปิดการเชื่อมต่อทันทีเมื่อ auth/connect ไม่ผ่าน
      _client.disconnect();
    }

    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      // ฟังทั้ง shadow update และสถานะที่อุปกรณ์ publish เอง
      _client.subscribe('@shadow/data/update', MqttQos.atMostOnce);
      _client.subscribe('@msg/home/device_status', MqttQos.atMostOnce);
      _client.updates!.listen(_onMessage);
    } else {
      onConnectionChanged(false);
    }
  }

  // รับข้อความจาก MQTT แล้วแปลงเป็น MqttShadowUpdate
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    final recMsg = events[0].payload as MqttPublishMessage;
    final payload = MqttPublishPayload.bytesToStringAsString(
      recMsg.payload.message,
    );

    try {
      final decoded = json.decode(payload);
      if (decoded is! Map) {
        return;
      }

      final map = Map<String, dynamic>.from(decoded);
      final nestedData =
          map['data'] is Map
              ? Map<String, dynamic>.from(map['data'] as Map)
              : <String, dynamic>{};
      final source = nestedData.isNotEmpty ? nestedData : map;

      final raw = _asInt(source['raw']);
      // ถ้าไม่มี bac ใน payload ให้คำนวณจาก raw เป็นค่า fallback
      final bacFromRaw = (raw / 4095.0) * 100.0;

      final update = MqttShadowUpdate(
        bac: _asDouble(
          source['bac'] ?? source['alcohol'] ?? source['alcoholValue'],
          fallback: bacFromRaw,
        ),
        raw: raw,
        threshold1: _asDouble(source['threshold1'], fallback: 20.0),
        threshold2: _asDouble(source['threshold2'], fallback: 50.0),
        alertLevel: _asInt(source['alertLevel']),
      );

      onShadowUpdate(update);
    } catch (_) {
      // ข้าม payload ที่ format ผิดโดยไม่ทำให้แอปล่ม
    }
  }

  // callback เมื่อ MQTT เชื่อมต่อสำเร็จ
  void _onConnected() {
    onConnectionChanged(true);
  }

  // callback เมื่อ MQTT หลุดการเชื่อมต่อ
  void _onDisconnected() {
    onConnectionChanged(false);
  }

  // ปิดการเชื่อมต่อ MQTT ด้วยตัวเอง
  void disconnect() {
    _client.disconnect();
  }
}
