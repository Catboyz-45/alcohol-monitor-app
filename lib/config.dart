// ค่าคอนฟิกทั้งหมดของแอป อ่านจาก --dart-define-from-file=config.json
// รวมไว้ที่เดียวเพื่อให้รู้ว่าแอปต้องใช้ค่าอะไรบ้าง และเช็กได้ว่าตั้งค่าครบหรือยัง
class AppConfig {
  const AppConfig._();

  // MQTT (NETPIE) — ใช้ credential ของ device ฝั่งแอปเท่านั้น (อยู่ group เดียวกับบอร์ด)
  // ไม่ต้องใช้ token ของบอร์ด จึงไม่มีใครแกะจากแอปไปปลอมเป็นบอร์ดได้
  static const String mqttHost = String.fromEnvironment(
    'APP_MQTT_HOST',
    defaultValue: 'mqtt.netpie.io',
  );
  static const int mqttPort = int.fromEnvironment(
    'APP_MQTT_PORT',
    defaultValue: 8883,
  );
  static const bool mqttTls = bool.fromEnvironment(
    'APP_MQTT_TLS',
    defaultValue: true,
  );
  static const String mqttWsUrl = String.fromEnvironment(
    'APP_MQTT_WS_URL',
    defaultValue: 'wss://mqtt.netpie.io:443/mqtt',
  );
  static const String mqttClientId = String.fromEnvironment(
    'APP_MQTT_CLIENT_ID',
  );
  static const String mqttUser = String.fromEnvironment('APP_MQTT_USER');
  static const String mqttPassword = String.fromEnvironment(
    'APP_MQTT_PASSWORD',
  );

  // Firebase (Auth + Firestore ผ่าน REST API)
  static const String firebaseProjectId = String.fromEnvironment(
    'APP_FIREBASE_PROJECT_ID',
  );
  static const String firebaseApiKey = String.fromEnvironment(
    'APP_FIREBASE_API_KEY',
  );

  static bool get hasMqtt => mqttClientId.isNotEmpty && mqttUser.isNotEmpty;

  // ไม่ได้ตั้งค่า MQTT → ใช้อุปกรณ์จำลองแทน
  static bool get hasDevice => hasMqtt;

  static bool get hasFirebase =>
      firebaseProjectId.isNotEmpty && firebaseApiKey.isNotEmpty;
}
