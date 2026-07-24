import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MeasurementRecord {
  final String id;
  final String name;
  final String idCard;
  final int age;
  final String licensePlate;
  final String province;
  final double alcoholValue;
  final String status;
  final DateTime timestamp;

  const MeasurementRecord({
    required this.id,
    required this.name,
    required this.idCard,
    required this.age,
    required this.licensePlate,
    required this.province,
    required this.alcoholValue,
    required this.status,
    required this.timestamp,
  });

  // แปลงโมเดลเป็น JSON เพื่อเก็บ local หรือส่งต่อ
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'idCard': idCard,
      'age': age,
      'licensePlate': licensePlate,
      'province': province,
      'alcoholValue': alcoholValue,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // สร้างโมเดลจาก JSON โดยมีค่า fallback กันข้อมูลไม่ครบ
  factory MeasurementRecord.fromJson(Map<String, dynamic> json) {
    return MeasurementRecord(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      idCard: json['idCard']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      licensePlate: json['licensePlate']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      alcoholValue: (json['alcoholValue'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'SAFE',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class AppState extends ChangeNotifier {
  static const String _recordsKey = 'measurement_records';
  static const String _firebaseProjectId = String.fromEnvironment(
    'APP_FIREBASE_PROJECT_ID',
  );
  static const String _firebaseApiKey = String.fromEnvironment(
    'APP_FIREBASE_API_KEY',
  );

  static String get _firestoreBaseUrl =>
      'https://firestore.googleapis.com/v1/projects/$_firebaseProjectId/databases/(default)/documents';

  static void _requireFirestoreConfig() {
    if (_firebaseProjectId.isEmpty || _firebaseApiKey.isEmpty) {
      throw StateError('Firebase configuration is missing');
    }
  }

  bool connected = false;
  bool buzzerOn = false;
  bool ledOn = false;

  int threshold = 20;
  int threshold2 = 50;

  double alcohol = 0.0;
  double? latestBoardAlcohol;
  String status = 'SAFE';
  DateTime? lastUpdate;
  String lastPayload = '{}';

  final List<MeasurementRecord> _records = [];

  // ส่งรายการแบบอ่านอย่างเดียว ป้องกันแก้จากภายนอก
  List<MeasurementRecord> get records => List.unmodifiable(_records);

  // โหลดประวัติ: พยายามดึงจาก Firestore ก่อน แล้ว fallback local cache
  Future<void> loadRecords() async {
    try {
      final cloudRecords = await _loadRecordsFromFirestore();
      _records
        ..clear()
        ..addAll(cloudRecords);
      await _saveRecords();
      notifyListeners();
      return;
    } catch (_) {
      // ถ้า cloud ใช้ไม่ได้ ให้ใช้ข้อมูลในเครื่องแทน
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return;
    }

    _records
      ..clear()
      ..addAll(
        decoded.whereType<Map>().map(
          (e) => MeasurementRecord.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  // บันทึกรายการทั้งหมดลง SharedPreferences
  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_records.map((e) => e.toJson()).toList());
    await prefs.setString(_recordsKey, raw);
  }

  // เพิ่มรายการใหม่ โดยพยายาม sync cloud ก่อนเสมอ
  Future<void> addRecord(MeasurementRecord record) async {
    try {
      await _upsertRecordToFirestore(record);
    } catch (_) {
      // แม้ cloud ล้มเหลว ก็ยังเพิ่มในเครื่องเพื่อไม่ให้ UX สะดุด
    }

    _records.insert(0, record);
    await _saveRecords();
    notifyListeners();
  }

  // ลบรายการตาม id และพยายามลบที่ cloud ด้วย
  Future<void> removeRecord(String id) async {
    try {
      await _deleteRecordFromFirestore(id);
    } catch (_) {
      // ลบในเครื่องต่อ แม้ลบบน cloud ไม่สำเร็จ
    }

    _records.removeWhere((e) => e.id == id);
    await _saveRecords();
    notifyListeners();
  }

  // อ่านข้อมูลจาก Firestore collection measurements
  Future<List<MeasurementRecord>> _loadRecordsFromFirestore() async {
    _requireFirestoreConfig();
    final url = Uri.parse(
      '$_firestoreBaseUrl/measurements?key=$_firebaseApiKey&orderBy=timestamp%20desc',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to load records from Firestore');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = (decoded['documents'] as List<dynamic>?) ?? const [];
    // แปลงเอกสาร Firestore เป็นโมเดลของแอป
    final records =
        docs
            .whereType<Map<String, dynamic>>()
            .map(_recordFromFirestoreDoc)
            .toList();

    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  // อัปเดตหรือสร้าง record เดิมด้วย document id เดียวกัน
  Future<void> _upsertRecordToFirestore(MeasurementRecord record) async {
    _requireFirestoreConfig();
    final url = Uri.parse(
      '$_firestoreBaseUrl/measurements/${record.id}?key=$_firebaseApiKey',
    );

    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fields': _toFirestoreFields(record)}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save record to Firestore');
    }
  }

  // ลบ record ที่ Firestore (404 ถือว่าลบไปแล้ว)
  Future<void> _deleteRecordFromFirestore(String id) async {
    _requireFirestoreConfig();
    final url = Uri.parse(
      '$_firestoreBaseUrl/measurements/$id?key=$_firebaseApiKey',
    );

    final response = await http.delete(url);
    if (response.statusCode != 200 && response.statusCode != 404) {
      throw Exception('Failed to delete record from Firestore');
    }
  }

  // แปลงโมเดลให้ตรงรูปแบบ fields ของ Firestore REST API
  Map<String, dynamic> _toFirestoreFields(MeasurementRecord record) {
    return {
      'id': {'stringValue': record.id},
      'name': {'stringValue': record.name},
      'idCard': {'stringValue': record.idCard},
      'age': {'integerValue': record.age.toString()},
      'licensePlate': {'stringValue': record.licensePlate},
      'province': {'stringValue': record.province},
      'alcoholValue': {'doubleValue': record.alcoholValue},
      'status': {'stringValue': record.status},
      'timestamp': {'stringValue': record.timestamp.toIso8601String()},
    };
  }

  // แปลงเอกสาร Firestore กลับเป็น MeasurementRecord
  MeasurementRecord _recordFromFirestoreDoc(Map<String, dynamic> doc) {
    final fields = (doc['fields'] as Map<String, dynamic>?) ?? const {};
    final timestampRaw = _readStringField(fields, 'timestamp');
    return MeasurementRecord(
      id: _readStringField(fields, 'id'),
      name: _readStringField(fields, 'name'),
      idCard: _readStringField(fields, 'idCard'),
      age: _readIntField(fields, 'age'),
      licensePlate: _readStringField(fields, 'licensePlate'),
      province: _readStringField(fields, 'province'),
      alcoholValue: _readDoubleField(fields, 'alcoholValue'),
      status: _readStringField(fields, 'status', fallback: 'SAFE'),
      timestamp: DateTime.tryParse(timestampRaw) ?? DateTime.now(),
    );
  }

  // อ่าน field แบบข้อความ รองรับทั้ง stringValue และ timestampValue
  String _readStringField(
    Map<String, dynamic> fields,
    String key, {
    String fallback = '',
  }) {
    final node = fields[key] as Map<String, dynamic>?;
    if (node == null) {
      return fallback;
    }
    final value = node['stringValue'] ?? node['timestampValue'];
    return value?.toString() ?? fallback;
  }

  // อ่าน field แบบจำนวนเต็ม รองรับ integer/double/string
  int _readIntField(Map<String, dynamic> fields, String key) {
    final node = fields[key] as Map<String, dynamic>?;
    if (node == null) {
      return 0;
    }

    final value = node['integerValue'] ?? node['doubleValue'];
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  // อ่าน field แบบทศนิยม รองรับ double/integer/string
  double _readDoubleField(Map<String, dynamic> fields, String key) {
    final node = fields[key] as Map<String, dynamic>?;
    if (node == null) {
      return 0.0;
    }

    final value = node['doubleValue'] ?? node['integerValue'];
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }

  // อัปเดตสถานะการเชื่อมต่ออุปกรณ์
  void setConnection(bool value) {
    connected = value;
    notifyListeners();
  }

  // อัปเดตเกณฑ์แรก และบังคับไม่ให้เกินเกณฑ์สอง
  void updateThreshold(int value) {
    // จำกัดค่าให้อยู่ในช่วงที่ระบบรองรับ
    threshold = value.clamp(0, 100);
    if (threshold > threshold2) {
      threshold2 = threshold;
    }
    _recomputeStatus();
  }

  // อัปเดตเกณฑ์สอง และบังคับไม่ให้ต่ำกว่าเกณฑ์แรก
  void updateThreshold2(int value) {
    // จำกัดค่าให้อยู่ในช่วงที่ระบบรองรับ
    threshold2 = value.clamp(0, 100);
    if (threshold2 < threshold) {
      threshold = threshold2;
    }
    _recomputeStatus();
  }

  // เก็บสถานะ buzzer ที่แสดงบน UI
  void updateBuzzerState(bool value) {
    buzzerOn = value;
    notifyListeners();
  }

  // เก็บสถานะ LED ที่แสดงบน UI
  void updateLedState(bool value) {
    ledOn = value;
    notifyListeners();
  }

  // อัปเดตค่าแอลกอฮอล์จากแหล่งอื่นที่ไม่ใช่ payload shadow
  void updateAlcohol(double value) {
    alcohol = value;
    lastUpdate = DateTime.now();
    _recomputeStatus();
  }

  // อัปเดตค่าทั้งชุดจากอุปกรณ์ (MQTT/HTTP)
  void updateFromDevice({
    required double bac,
    required int alertLevel,
    required double threshold1,
    required double threshold2,
    required int raw,
  }) {
    // ปัดเศษและคุมช่วง threshold ก่อนใช้คำนวณสถานะ
    threshold = threshold1.round().clamp(0, 100);
    this.threshold2 = threshold2.round().clamp(0, 100);
    alcohol = bac;
    latestBoardAlcohol = bac;
    lastUpdate = DateTime.now();

    if (alertLevel >= 2) {
      status = 'DRUNK';
    } else if (alertLevel == 1) {
      status = 'WARNING';
    } else {
      status = 'SAFE';
    }

    // เก็บ payload ล่าสุดไว้สำหรับ debug/แสดงผล
    final payloadMap = {
      'bac': bac,
      'raw': raw,
      'threshold1': threshold,
      'threshold2': this.threshold2,
      'alertLevel': alertLevel,
      'status': status,
      'updatedAt': lastUpdate!.toIso8601String(),
    };
    lastPayload = jsonEncode(payloadMap);
    notifyListeners();
  }

  // รีเซ็ตค่าหน้าจอวัดกลับค่าเริ่มต้น
  void resetAlcohol() {
    alcohol = 0.0;
    status = 'SAFE';
    lastUpdate = DateTime.now();
    notifyListeners();
  }

  // คำนวณสถานะจากค่า alcohol เทียบ threshold ปัจจุบัน
  void _recomputeStatus() {
    if (alcohol >= threshold2) {
      status = 'DRUNK';
    } else if (alcohol >= threshold) {
      status = 'WARNING';
    } else {
      status = 'SAFE';
    }
    notifyListeners();
  }
}
