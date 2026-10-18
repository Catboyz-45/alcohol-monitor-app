import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

// ฟังก์ชันนี้สร้าง MQTT client สำหรับแพลตฟอร์มเว็บที่ใช้การเชื่อมต่อแบบ WebSocket
// MqttBrowserClient จะแทนพอร์ตใน URL ด้วย client.port (ค่าเริ่มต้น 1883)
// จึงต้องส่งพอร์ตจาก wsUrl เข้าไปเอง ไม่อย่างนั้นจะต่อไปที่ wss://host:1883
MqttClient createPlatformMqttClient({
  required String clientId,
  required String host,
  required int port,
  required bool useTls,
  required String wsUrl,
}) {
  final uri = Uri.parse(wsUrl);
  final wsPort = uri.hasPort ? uri.port : (uri.scheme == 'ws' ? 80 : 443);
  return MqttBrowserClient.withPort(wsUrl, clientId, wsPort);
}
