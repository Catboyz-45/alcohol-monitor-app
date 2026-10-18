import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// ฟังก์ชันนี้สร้าง MQTT client สำหรับแพลตฟอร์มที่รองรับการเชื่อมต่อแบบ TCP
// ค่าเริ่มต้นใช้ TLS (NETPIE MQTTS พอร์ต 1884) เพื่อไม่ให้ token วิ่งเป็น plaintext
MqttClient createPlatformMqttClient({
  required String clientId,
  required String host,
  required int port,
  required bool useTls,
  required String wsUrl,
}) {
  final client = MqttServerClient.withPort(host, clientId, port);
  client.secure = useTls;
  return client;
}
