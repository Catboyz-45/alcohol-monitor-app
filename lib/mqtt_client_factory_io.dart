import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// ฟังก์ชันนี้สร้าง MQTT client สำหรับแพลตฟอร์มที่รองรับการเชื่อมต่อแบบ TCP
// ค่าเริ่มต้นใช้ TLS พอร์ต 8883 (ใบรับรอง public CA ตรวจผ่าน) เพื่อไม่ให้ token วิ่งเป็น plaintext
// พอร์ต 1884 ของ NETPIE ใช้ CA ส่วนตัวของ NEXPIE แอปทั่วไปจะตรวจใบรับรองไม่ผ่าน
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
