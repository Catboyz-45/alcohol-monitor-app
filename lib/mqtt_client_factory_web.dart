import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

// ฟังก์ชันนี้สร้าง MQTT client สำหรับแพลตฟอร์มเว็บที่ใช้การเชื่อมต่อแบบ WebSocket
MqttClient createPlatformMqttClient({
  required String clientId,
  required String host,
  required String wsUrl,
}) {
  return MqttBrowserClient(wsUrl, clientId);
}
