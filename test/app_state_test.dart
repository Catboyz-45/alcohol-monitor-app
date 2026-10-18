import 'package:alcohol_monitor_app/app_state.dart';
import 'package:alcohol_monitor_app/device_reading.dart';
import 'package:alcohol_monitor_app/firestore_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRemote implements RecordsRemote {
  final Map<String, MeasurementRecord> docs = {};
  bool online = true;
  int upserts = 0;

  void _check() {
    if (!online) {
      throw Exception('offline');
    }
  }

  @override
  Future<List<MeasurementRecord>> fetchAll() async {
    _check();
    return docs.values.map((r) => r.copyWith(synced: true)).toList();
  }

  @override
  Future<void> upsert(MeasurementRecord record) async {
    _check();
    upserts++;
    docs[record.id] = record;
  }

  @override
  Future<void> delete(String id) async {
    _check();
    docs.remove(id);
  }
}

MeasurementRecord record(String id, {int minute = 0}) => MeasurementRecord(
  id: id,
  name: 'ทดสอบ $id',
  idCard: '1101700203450',
  age: 30,
  licensePlate: '1กก 1234',
  province: 'กรุงเทพมหานคร',
  alcoholValue: 25,
  status: 'WARNING',
  timestamp: DateTime(2026, 10, 18, 10, minute),
);

DeviceReading reading(double bac, {double t1 = 20, double t2 = 50}) =>
    DeviceReading(
      bac: bac,
      threshold1: t1,
      threshold2: t2,
      alertLevel: alertLevelFor(bac, t1, t2),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ประวัติและการซิงก์', () {
    test('บันทึกตอน cloud ล่ม แล้วโหลดใหม่ รายการต้องไม่หาย', () async {
      final remote = FakeRemote()..docs['old'] = record('old');
      final state = AppState(remote: remote);
      await state.loadRecords();
      expect(state.records.map((r) => r.id), ['old']);

      remote.online = false;
      await state.addRecord(record('new', minute: 5));
      expect(state.pendingSyncCount, 1);
      expect(state.syncError, isNotNull);

      // เดิม loadRecords() เขียนทับด้วยข้อมูลจาก cloud ทำให้ 'new' หาย
      remote.online = true;
      final reopened = AppState(remote: remote);
      await reopened.loadRecords();

      expect(reopened.records.map((r) => r.id), ['new', 'old']);
      expect(reopened.pendingSyncCount, 0);
      expect(remote.docs.keys, containsAll(['old', 'new']));
      expect(reopened.syncError, isNull);
    });

    test('ลบตอน cloud ล่ม จะลบบน cloud ให้ภายหลัง และไม่โผล่กลับมา', () async {
      final remote = FakeRemote();
      final state = AppState(remote: remote);
      await state.loadRecords();
      await state.addRecord(record('a'));
      expect(remote.docs.containsKey('a'), isTrue);

      remote.online = false;
      await state.removeRecord('a');
      expect(state.records, isEmpty);
      expect(state.pendingSyncCount, 1);

      remote.online = true;
      await state.syncNow();
      expect(state.records, isEmpty);
      expect(remote.docs.containsKey('a'), isFalse);
      expect(state.pendingSyncCount, 0);
    });

    test('ลบรายการที่ยังไม่เคยขึ้น cloud ไม่ต้องเรียก cloud', () async {
      final remote = FakeRemote()..online = false;
      final state = AppState(remote: remote);
      await state.addRecord(record('local'));
      await state.removeRecord('local');
      expect(state.pendingSyncCount, 0);
    });

    test('โหมดไม่มี cloud เก็บในเครื่องอย่างเดียว', () async {
      final state = AppState();
      await state.loadRecords();
      await state.addRecord(record('x'));

      final reopened = AppState();
      await reopened.loadRecords();
      expect(reopened.records.single.id, 'x');
      expect(reopened.hasCloud, isFalse);
    });

    test('ข้อมูลโหมดสาธิตแยก key จากข้อมูลจริง', () async {
      final demo = AppState(storageKey: 'demo_measurement_records');
      await demo.addRecord(record('demo'));

      final real = AppState();
      await real.loadRecords();
      expect(real.records, isEmpty);
    });

    test('รายการที่ซิงก์แล้วไม่เก็บเลขบัตรเต็มในเครื่อง', () async {
      final remote = FakeRemote();
      final state = AppState(remote: remote);
      await state.addRecord(record('synced'));
      remote.online = false;
      await state.addRecord(record('pending', minute: 1));

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('measurement_records')!;
      // รายการที่รอส่งต้องเก็บเลขเต็มไว้ส่ง ส่วนที่ซิงก์แล้วเหลือ 3 หลักท้าย
      expect(RegExp('1101700203450').allMatches(stored), hasLength(1));
      expect(stored, contains('XXXXXXXXXX450'));

      // เปิดแอปออฟไลน์ เห็นแบบปิดไว้ พอออนไลน์ก็ได้เลขเต็มจาก cloud
      final reopened = AppState(remote: remote);
      await reopened.loadRecords();
      final synced = reopened.records.firstWhere((r) => r.id == 'synced');
      expect(synced.idCard, 'XXXXXXXXXX450');

      remote.online = true;
      await reopened.syncNow();
      expect(
        reopened.records.firstWhere((r) => r.id == 'synced').idCard,
        '1101700203450',
      );
      expect(remote.docs['pending']!.idCard, '1101700203450');
    });

    test('ออกจากระบบแล้วล้างข้อมูลในเครื่อง', () async {
      final state = AppState();
      await state.addRecord(record('x'));
      await state.clearLocalData();

      final reopened = AppState();
      await reopened.loadRecords();
      expect(reopened.records, isEmpty);
    });
  });

  group('สถานะอุปกรณ์', () {
    test('online เมื่อได้ข้อมูลสด และ stale เมื่อเงียบเกิน 12 วินาที', () {
      var now = DateTime(2026, 10, 18, 12);
      final state = AppState(clock: () => now);
      expect(state.link, LinkState.connecting);

      state.applyReading(reading(5));
      expect(state.link, LinkState.online);

      now = now.add(const Duration(seconds: 11));
      expect(state.link, LinkState.online);

      now = now.add(const Duration(seconds: 2));
      expect(state.link, LinkState.stale);
    });

    test('MQTT หลุดแสดงว่าไม่ได้เชื่อมต่อทันที แม้เพิ่งได้ข้อมูล', () {
      final state = AppState();
      state.setMqttConnected(true);
      state.applyReading(reading(5));
      expect(state.link, LinkState.online);

      state.setMqttConnected(false);
      expect(state.link, LinkState.offline);
    });

    test('จำค่าสูงสุดของการเป่า และไม่นับค่าพื้นหลังของเซนเซอร์', () {
      final state = AppState();
      state.applyReading(reading(4));
      expect(state.peakBac, isNull);
      expect(state.measuredValue, 4);

      state.applyReading(reading(35));
      state.applyReading(reading(62));
      state.applyReading(reading(18));
      expect(state.peakBac, 62);
      expect(state.measuredValue, 62);
      expect(state.measuredStatus, AlertStatus.danger);

      state.resetPeak();
      expect(state.measuredValue, 18);
      expect(state.measuredStatus, AlertStatus.safe);
    });

    test('ยืนยัน threshold เมื่ออุปกรณ์รายงานค่าใหม่กลับมา', () {
      var now = DateTime(2026, 10, 18, 12);
      final state = AppState(clock: () => now);
      state.markThresholdsSent(30, 60);
      expect(state.pendingThresholds, isNotNull);

      state.applyReading(reading(5));
      expect(state.pendingThresholds, isNotNull);

      now = now.add(const Duration(seconds: 16));
      expect(state.thresholdsAckOverdue, isTrue);

      state.applyReading(reading(5, t1: 30, t2: 60));
      expect(state.pendingThresholds, isNull);
      expect(state.thresholdsConfirmedAt, now);
      expect(state.thresholdsAckOverdue, isFalse);
    });
  });
}
