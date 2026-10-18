// ค่าคอนฟิกทั้งหมดของแอป อ่านจาก --dart-define-from-file=config.json
// รวมไว้ที่เดียวเพื่อให้รู้ว่าแอปต้องใช้ค่าอะไรบ้าง และเช็กได้ว่าตั้งค่าครบหรือยัง
class AppConfig {
  const AppConfig._();

  // MQTT (NETPIE) — client id ต้องเป็น Client ID ของ device ฝั่งแอปใน NETPIE
  static const String mqttHost = String.fromEnvironment(
    'APP_MQTT_HOST',
    defaultValue: 'mqtt.netpie.io',
  );
  static const int mqttPort = int.fromEnvironment(
    'APP_MQTT_PORT',
    defaultValue: 1884,
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

  // NETPIE REST API
  static const String netpieControlUrl = String.fromEnvironment(
    'APP_NETPIE_CONTROL_URL',
    defaultValue:
        'https://api.netpie.io/v2/device/message?topic=home/device_control',
  );
  static const String netpieStatusUrl = String.fromEnvironment(
    'APP_NETPIE_STATUS_URL',
    defaultValue: 'https://api.netpie.io/v2/device/shadow/data',
  );
  static const String netpieControlClientId = String.fromEnvironment(
    'APP_NETPIE_CONTROL_CLIENT_ID',
  );
  static const String netpieControlToken = String.fromEnvironment(
    'APP_NETPIE_CONTROL_TOKEN',
  );
  static const String netpieStatusClientId = String.fromEnvironment(
    'APP_NETPIE_STATUS_CLIENT_ID',
  );
  static const String netpieStatusToken = String.fromEnvironment(
    'APP_NETPIE_STATUS_TOKEN',
  );

  // Firebase (Auth + Firestore ผ่าน REST API)
  static const String firebaseProjectId = String.fromEnvironment(
    'APP_FIREBASE_PROJECT_ID',
  );
  static const String firebaseApiKey = String.fromEnvironment(
    'APP_FIREBASE_API_KEY',
  );

  static bool get hasMqtt => mqttClientId.isNotEmpty && mqttUser.isNotEmpty;

  static bool get hasNetpieStatus =>
      netpieStatusClientId.isNotEmpty && netpieStatusToken.isNotEmpty;

  static bool get hasNetpieControl =>
      netpieControlClientId.isNotEmpty && netpieControlToken.isNotEmpty;

  // ไม่มีช่องทางคุยกับอุปกรณ์เลย → ใช้อุปกรณ์จำลองแทน
  static bool get hasDevice => hasMqtt || hasNetpieStatus;

  static bool get hasFirebase =>
      firebaseProjectId.isNotEmpty && firebaseApiKey.isNotEmpty;
}
