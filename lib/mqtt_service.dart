import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';

import 'config.dart';
import 'device_reading.dart';
import 'mqtt_client_factory.dart';

// topic ที่ firmware publish ผลวัดและ heartbeat (ต้องอยู่ group เดียวกันใน NETPIE)
// หมายเหตุ: @shadow/data/update เป็น topic สำหรับ "เขียน" shadow ของตัวเอง
// subscribe แล้วไม่ได้ข้อมูลของอุปกรณ์ตัวอื่น จึงอ่าน shadow ผ่าน REST แทน
const String kDeviceStatusTopic = '@msg/home/device_status';

class MqttService {
  final String clientId;
  final String username;
  final String password;
  final void Function(DeviceReading) onReading;
  final void Function(bool) onConnectionChanged;

  MqttClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;

  MqttService({
    required this.clientId,
    required this.username,
    required this.password,
    required this.onReading,
    required this.onConnectionChanged,
  });

  // แปลง payload ดิบจาก broker เป็น DeviceReading (null ถ้า format ผิด)
  static DeviceReading? parsePayload(String payload) {
    try {
      return DeviceReading.tryParse(json.decode(payload));
    } on FormatException {
      return null;
    }
  }

  // เชื่อมต่อ broker และ subscribe topic ที่ต้องใช้
  Future<void> connect() async {
    final client = createMqttClient(
      clientId: clientId,
      host: AppConfig.mqttHost,
      port: AppConfig.mqttPort,
      useTls: AppConfig.mqttTls,
      wsUrl: AppConfig.mqttWsUrl,
    );
    _client = client;

    client.keepAlivePeriod = 20;
    // ให้ไลบรารีต่อใหม่เองเมื่อหลุด และ subscribe topic เดิมให้อัตโนมัติ
    client.autoReconnect = true;
    client.onConnected = () => onConnectionChanged(true);
    client.onDisconnected = () => onConnectionChanged(false);
    client.onAutoReconnect = () => onConnectionChanged(false);
    client.onAutoReconnected = () => onConnectionChanged(true);
    client.connectionMessage =
        MqttConnectMessage()
            .withClientIdentifier(clientId)
            .authenticateAs(username, password)
            .startClean();

    try {
      await client.connect();
    } catch (_) {
      // ปิดการเชื่อมต่อทันทีเมื่อ auth/connect ไม่ผ่าน
      client.disconnect();
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      onConnectionChanged(false);
      return;
    }

    client.subscribe(kDeviceStatusTopic, MqttQos.atMostOnce);
    _updates = client.updates?.listen(_onMessage);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final message = event.payload;
      if (message is! MqttPublishMessage) {
        continue;
      }
      final payload = MqttPublishPayload.bytesToStringAsString(
        message.payload.message,
      );
      final reading = parsePayload(payload);
      if (reading != null) {
        onReading(reading);
      }
    }
  }

  // ปิดการเชื่อมต่อ MQTT ด้วยตัวเอง
  void disconnect() {
    _updates?.cancel();
    _client?.autoReconnect = false;
    _client?.disconnect();
  }
}
