import 'dart:convert';

import 'package:alcohol_monitor_app/firestore_repository.dart';
import 'package:alcohol_monitor_app/measurement_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> doc(String id, String timestamp) => {
  'name': 'projects/p/databases/(default)/documents/measurements/$id',
  'fields': {
    'name': {'stringValue': 'ผู้ทดสอบ'},
    'idCard': {'stringValue': '1101700203450'},
    'age': {'integerValue': '41'},
    'alcoholValue': {'doubleValue': 33.3},
    'status': {'stringValue': 'WARNING'},
    'timestamp': {'timestampValue': timestamp},
  },
};

void main() {
  test('แนบ Bearer token และอ่านครบทุกหน้า', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final page = request.url.queryParameters['pageToken'];
      final body =
          page == null
              ? {
                'documents': [doc('a', '2026-10-18T01:00:00Z')],
                'nextPageToken': 'p2',
              }
              : {
                'documents': [doc('b', '2026-10-18T02:00:00Z')],
              };
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });

    final repo = FirestoreRepository(
      idToken: () async => 'token-123',
      uid: 'u1',
      client: client,
      projectId: 'p',
    );
    final records = await repo.fetchAll();

    expect(requests, hasLength(2));
    expect(requests.first.headers['Authorization'], 'Bearer token-123');
    expect(requests.first.url.queryParameters.containsKey('key'), isFalse);
    // เรียงจากใหม่ไปเก่า และใช้ id จากชื่อเอกสารเมื่อไม่มี field id
    expect(records.map((r) => r.id), ['b', 'a']);
    expect(records.first.age, 41);
    expect(records.first.synced, isTrue);
  });

  test('403 จาก Security Rules แปลงเป็น PermissionDeniedException', () async {
    final repo = FirestoreRepository(
      idToken: () async => 't',
      uid: 'u1',
      client: MockClient((_) async => http.Response('{}', 403)),
      projectId: 'p',
    );
    expect(repo.fetchAll(), throwsA(isA<PermissionDeniedException>()));
  });

  test('ลบเอกสารที่ไม่มีอยู่แล้ว (404) ไม่ถือว่าผิดพลาด', () async {
    final repo = FirestoreRepository(
      idToken: () async => 't',
      uid: 'u1',
      client: MockClient((_) async => http.Response('{}', 404)),
      projectId: 'p',
    );
    await repo.delete('gone');
  });

  test('upsert ส่ง timestampValue แบบ UTC และ createdBy', () async {
    late Map<String, dynamic> sent;
    final repo = FirestoreRepository(
      idToken: () async => 't',
      uid: 'officer-1',
      client: MockClient((request) async {
        expect(request.method, 'PATCH');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }),
      projectId: 'p',
    );
    await repo.upsert(
      MeasurementRecord(
        id: '1',
        name: 'ก',
        idCard: '1101700203450',
        age: 20,
        licensePlate: 'กก 1',
        province: 'ตาก',
        alcoholValue: 12.5,
        status: 'SAFE',
        timestamp: DateTime.utc(2026, 10, 18, 3),
      ),
    );

    final fields = sent['fields'] as Map<String, dynamic>;
    expect(fields['timestamp'], {'timestampValue': '2026-10-18T03:00:00.000Z'});
    expect(fields['createdBy'], {'stringValue': 'officer-1'});
    expect(fields.containsKey('synced'), isFalse);
  });

  test('อ่านเอกสารรูปแบบเก่าที่เก็บ timestamp เป็น string ได้', () {
    final record = FirestoreRepository.recordFromFirestoreDoc({
      'fields': {
        'id': {'stringValue': 'legacy'},
        'timestamp': {'stringValue': '2025-01-02T03:04:05.000'},
        'age': {'integerValue': '30'},
      },
    });
    expect(record.id, 'legacy');
    expect(record.timestamp.year, 2025);
    expect(record.status, 'SAFE');
  });
}
