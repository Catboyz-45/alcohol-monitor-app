import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// ฟังก์ชันนี้สร้าง MQTT client สำหรับแพลตฟอร์มที่รองรับการเชื่อมต่อแบบ TCP
MqttClient createPlatformMqttClient({
  required String clientId,
  required String host,
  required String wsUrl,
}) {
  final client = MqttServerClient(host, clientId);
  client.port = 1883;
  return client;
}
