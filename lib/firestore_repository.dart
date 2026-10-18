import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'measurement_record.dart';

class PermissionDeniedException implements Exception {
  @override
  String toString() =>
      'บัญชีนี้ยังไม่มีสิทธิ์เข้าถึงข้อมูล (ต้องเพิ่มใน collection officers)';
}

// ที่เก็บประวัติบน cloud แยกเป็น interface เพื่อให้เทสต์ AppState ได้โดยไม่ต่อเน็ต
abstract class RecordsRemote {
  Future<List<MeasurementRecord>> fetchAll();
  Future<void> upsert(MeasurementRecord record);
  Future<void> delete(String id);
}

// Cloud Firestore ผ่าน REST API โดยแนบ Firebase ID token ทุกคำขอ
class FirestoreRepository implements RecordsRemote {
  FirestoreRepository({
    required this.idToken,
    required this.uid,
    http.Client? client,
    String projectId = AppConfig.firebaseProjectId,
  }) : _client = client ?? http.Client(),
       _baseUrl =
           'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  final Future<String> Function() idToken;
  final String uid;
  final http.Client _client;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 10);

  Future<Map<String, String>> _headers() async => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${await idToken()}',
  };

  void _check(http.Response response, String action) {
    if (response.statusCode == 200) {
      return;
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw PermissionDeniedException();
    }
    throw Exception('$action ไม่สำเร็จ (HTTP ${response.statusCode})');
  }

  // อ่านทุกหน้า (Firestore REST แบ่งหน้าด้วย nextPageToken)
  @override
  Future<List<MeasurementRecord>> fetchAll() async {
    final records = <MeasurementRecord>[];
    String? pageToken;
    do {
      final uri = Uri.parse('$_baseUrl/measurements').replace(
        queryParameters: {
          'pageSize': '300',
          if (pageToken != null) 'pageToken': pageToken,
        },
      );
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(_timeout);
      _check(response, 'โหลดประวัติ');

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final docs = (decoded['documents'] as List<dynamic>?) ?? const [];
      records.addAll(
        docs.whereType<Map<String, dynamic>>().map(recordFromFirestoreDoc),
      );
      pageToken = decoded['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);

    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  // สร้างหรืออัปเดตเอกสารด้วย id เดียวกับในเครื่อง (ส่งซ้ำได้ไม่เกิดข้อมูลซ้ำ)
  @override
  Future<void> upsert(MeasurementRecord record) async {
    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/measurements/${Uri.encodeComponent(record.id)}'),
          headers: await _headers(),
          body: jsonEncode({'fields': toFirestoreFields(record, uid)}),
        )
        .timeout(_timeout);
    _check(response, 'บันทึกขึ้น cloud');
  }

  // ลบเอกสาร (404 ถือว่าลบไปแล้ว)
  @override
  Future<void> delete(String id) async {
    final response = await _client
        .delete(
          Uri.parse('$_baseUrl/measurements/${Uri.encodeComponent(id)}'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    if (response.statusCode == 404) {
      return;
    }
    _check(response, 'ลบข้อมูลบน cloud');
  }

  // แปลงโมเดลให้ตรงรูปแบบ fields ของ Firestore REST API
  // timestamp เก็บเป็น timestampValue (UTC) เพื่อให้เรียงลำดับและตรวจใน rules ได้
  static Map<String, dynamic> toFirestoreFields(
    MeasurementRecord record,
    String uid,
  ) {
    return {
      'id': {'stringValue': record.id},
      'name': {'stringValue': record.name},
      'idCard': {'stringValue': record.idCard},
      'age': {'integerValue': record.age.toString()},
      'licensePlate': {'stringValue': record.licensePlate},
      'province': {'stringValue': record.province},
      'alcoholValue': {'doubleValue': record.alcoholValue},
      'status': {'stringValue': record.status},
      'timestamp': {
        'timestampValue': record.timestamp.toUtc().toIso8601String(),
      },
      'createdBy': {'stringValue': uid},
    };
  }

  // แปลงเอกสาร Firestore กลับเป็น MeasurementRecord (รองรับข้อมูลรูปแบบเก่า)
  static MeasurementRecord recordFromFirestoreDoc(Map<String, dynamic> doc) {
    final fields = (doc['fields'] as Map<String, dynamic>?) ?? const {};
    final docName = doc['name']?.toString() ?? '';
    final idFromName = docName.isEmpty ? '' : docName.split('/').last;
    final id = _readString(fields, 'id');
    return MeasurementRecord(
      id: id.isEmpty ? idFromName : id,
      name: _readString(fields, 'name'),
      idCard: _readString(fields, 'idCard'),
      age: _readNum(fields, 'age').toInt(),
      licensePlate: _readString(fields, 'licensePlate'),
      province: _readString(fields, 'province'),
      alcoholValue: _readNum(fields, 'alcoholValue').toDouble(),
      status: _readString(fields, 'status', fallback: 'SAFE'),
      timestamp:
          DateTime.tryParse(_readString(fields, 'timestamp'))?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      synced: true,
    );
  }

  static String _readString(
    Map<String, dynamic> fields,
    String key, {
    String fallback = '',
  }) {
    final node = fields[key];
    if (node is! Map) {
      return fallback;
    }
    final value = node['stringValue'] ?? node['timestampValue'];
    return value?.toString() ?? fallback;
  }

  static num _readNum(Map<String, dynamic> fields, String key) {
    final node = fields[key];
    if (node is! Map) {
      return 0;
    }
    final value = node['doubleValue'] ?? node['integerValue'];
    if (value is num) {
      return value;
    }
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}
