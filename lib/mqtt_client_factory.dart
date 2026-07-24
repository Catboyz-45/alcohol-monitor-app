import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_client_factory_io.dart'
    if (dart.library.js_interop) 'mqtt_client_factory_web.dart';

// ฟังก์ชันนี้เป็นจุดเข้าหลักสำหรับการสร้าง MQTT client ที่เหมาะสมกับแพลตฟอร์มที่กำลังรันอยู่
MqttClient createMqttClient({
  required String clientId,
  required String host,
  required String wsUrl,
}) => createPlatformMqttClient(clientId: clientId, host: host, wsUrl: wsUrl);
