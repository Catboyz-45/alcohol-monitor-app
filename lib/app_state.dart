import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_reading.dart';
import 'firestore_repository.dart';
import 'measurement_record.dart';
import 'thai_id.dart';

export 'measurement_record.dart';

enum LinkState {
  // ยังไม่เคยได้ข้อมูลจากอุปกรณ์
  connecting,
  // อุปกรณ์ส่งข้อมูลมาภายในช่วงเวลาที่กำหนด
  online,
  // เคยได้ข้อมูล แต่อุปกรณ์เงียบไปนานเกินไป (ค่าที่เห็นอาจไม่ใช่ปัจจุบัน)
  stale,
  // ต่อ MQTT ไม่ได้
  offline,
}

class AppState extends ChangeNotifier {
  AppState({
    this.remote,
    this.storageKey = 'measurement_records',
    this.isDemo = false,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  // อุปกรณ์ถือว่าเงียบไปถ้าไม่มีข้อมูลใหม่เกินเวลานี้
  // (firmware ส่ง heartbeat ทุก 5 วินาที เผื่อหลุดได้ 1 รอบ)
  static const Duration staleAfter = Duration(seconds: 12);

  // ค่าต่ำกว่านี้ถือเป็นค่าพื้นหลังของเซนเซอร์ ไม่นับเป็นการเป่า
  // ตรงกับ MIN_REPORT_BAC ใน firmware
  static const double noiseFloor = 10.0;

  final RecordsRemote? remote;
  final String storageKey;
  final bool isDemo;
  final DateTime Function() _clock;

  String get _pendingDeletesKey => '${storageKey}_pending_deletes';

  // ---------------------------------------------------------------------------
  // ประวัติการวัด
  // ---------------------------------------------------------------------------

  final List<MeasurementRecord> _records = [];
  final Set<String> _pendingDeletes = {};
  bool _localLoaded = false;
  bool syncing = false;
  String? syncError;

  // ส่งรายการแบบอ่านอย่างเดียว ป้องกันแก้จากภายนอก
  List<MeasurementRecord> get records => List.unmodifiable(_records);

  int get pendingSyncCount =>
      _records.where((r) => !r.synced).length + _pendingDeletes.length;

  bool get hasCloud => remote != null;

  // โหลดข้อมูลในเครื่องก่อน แล้วซิงก์กับ cloud (ถ้ามี)
  Future<void> loadRecords() async {
    if (!_localLoaded) {
      await _loadLocal();
      _localLoaded = true;
      notifyListeners();
    }
    await syncNow();
  }

  // ส่งรายการที่ค้างขึ้น cloud แล้วดึงรายการล่าสุดมารวมกับของในเครื่อง
  Future<void> syncNow() async {
    final cloud = remote;
    if (cloud == null || syncing) {
      return;
    }
    syncing = true;
    notifyListeners();

    try {
      for (final id in _pendingDeletes.toList()) {
        await cloud.delete(id);
        _pendingDeletes.remove(id);
      }
      for (final record in _records.where((r) => !r.synced).toList()) {
        await cloud.upsert(record);
        _replace(record.copyWith(synced: true));
      }

      final cloudRecords = await cloud.fetchAll();
      final unsynced = _records.where((r) => !r.synced).toList();
      final merged = <String, MeasurementRecord>{
        for (final r in cloudRecords)
          if (!_pendingDeletes.contains(r.id)) r.id: r,
        // รายการที่ยังไม่ขึ้น cloud ต้องไม่หายไปเพราะโหลดทับ
        for (final r in unsynced) r.id: r,
      };
      _records
        ..clear()
        ..addAll(merged.values);
      _sortRecords();
      syncError = null;
    } catch (e) {
      syncError = e.toString();
    } finally {
      syncing = false;
      await _saveLocal();
      notifyListeners();
    }
  }

  // เพิ่มรายการในเครื่องทันที แล้วค่อยส่งขึ้น cloud (ถ้าล้มเหลวจะส่งใหม่รอบหน้า)
  Future<void> addRecord(MeasurementRecord record) async {
    _records.insert(0, record.copyWith(synced: false));
    _sortRecords();
    await _saveLocal();
    notifyListeners();

    final cloud = remote;
    if (cloud == null) {
      return;
    }
    try {
      await cloud.upsert(record);
      _replace(record.copyWith(synced: true));
      syncError = null;
    } catch (e) {
      syncError = e.toString();
    }
    await _saveLocal();
    notifyListeners();
  }

  // ลบในเครื่องทันที ถ้าเคยขึ้น cloud แล้วให้จำไว้ลบบน cloud จนกว่าจะสำเร็จ
  Future<void> removeRecord(String id) async {
    final index = _records.indexWhere((e) => e.id == id);
    if (index < 0) {
      return;
    }
    final removed = _records.removeAt(index);
    final cloud = remote;
    if (cloud != null && removed.synced) {
      _pendingDeletes.add(id);
    }
    await _saveLocal();
    notifyListeners();

    if (cloud == null || !removed.synced) {
      return;
    }
    try {
      await cloud.delete(id);
      _pendingDeletes.remove(id);
      syncError = null;
    } catch (e) {
      syncError = e.toString();
    }
    await _saveLocal();
    notifyListeners();
  }

  // ล้างข้อมูลในเครื่องเมื่อออกจากระบบ (ข้อมูลมีเลขบัตรประชาชน)
  Future<void> clearLocalData() async {
    _records.clear();
    _pendingDeletes.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    await prefs.remove(_pendingDeletesKey);
    notifyListeners();
  }

  void _replace(MeasurementRecord record) {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      _records[index] = record;
    }
  }

  void _sortRecords() {
    _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingDeletes
      ..clear()
      ..addAll(prefs.getStringList(_pendingDeletesKey) ?? const []);

    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
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
      _sortRecords();
    } on FormatException {
      // ข้อมูลในเครื่องเสีย ข้ามไปแทนที่จะทำให้แอปเปิดไม่ขึ้น
    }
  }

  // รายการที่ขึ้น cloud แล้วไม่จำเป็นต้องเก็บเลขบัตรเต็มในเครื่อง
  // (SharedPreferences ไม่เข้ารหัส) ส่วนรายการที่ยังรอส่งต้องเก็บเต็มไว้ส่งขึ้น cloud
  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final cloud = remote != null;
    await prefs.setString(
      storageKey,
      jsonEncode(
        _records
            .map(
              (e) =>
                  cloud && e.synced
                      ? e
                          .copyWith(idCard: redactIdForStorage(e.idCard))
                          .toJson()
                      : e.toJson(),
            )
            .toList(),
      ),
    );
    await prefs.setStringList(_pendingDeletesKey, _pendingDeletes.toList());
  }

  // ---------------------------------------------------------------------------
  // สถานะอุปกรณ์
  // ---------------------------------------------------------------------------

  DeviceReading? latest;
  DateTime? lastUpdate;
  // null = กำลังเชื่อมต่อครั้งแรก
  bool? mqttConnected;

  // ค่าสูงสุดของการเป่าครั้งนี้ (บอร์ดแสดงค่าค้างแค่ 2.5 วินาที
  // จึงต้องจำค่าสูงสุดไว้ให้เจ้าหน้าที่บันทึกได้ทัน)
  double? peakBac;
  DateTime? peakAt;

  // threshold ที่ส่งไปแล้วแต่อุปกรณ์ยังไม่ยืนยัน
  ({double t1, double t2})? pendingThresholds;
  DateTime? thresholdsSentAt;
  DateTime? thresholdsConfirmedAt;

  double get threshold1 => latest?.threshold1 ?? kDefaultThreshold1;
  double get threshold2 => latest?.threshold2 ?? kDefaultThreshold2;

  LinkState get link {
    if (mqttConnected == false) {
      return LinkState.offline;
    }
    final freshAt = lastUpdate;
    if (freshAt == null) {
      return LinkState.connecting;
    }
    return _clock().difference(freshAt) <= staleAfter
        ? LinkState.online
        : LinkState.stale;
  }

  // รับค่าจากอุปกรณ์ (ทุกข้อความจาก MQTT คือค่าสด)
  void applyReading(DeviceReading reading) {
    final now = _clock();
    latest = reading;
    lastUpdate = now;
    if (reading.bac > noiseFloor &&
        (peakBac == null || reading.bac > peakBac!)) {
      peakBac = reading.bac;
      peakAt = now;
    }

    final pending = pendingThresholds;
    if (pending != null &&
        (reading.threshold1 - pending.t1).abs() < 0.05 &&
        (reading.threshold2 - pending.t2).abs() < 0.05) {
      pendingThresholds = null;
      thresholdsConfirmedAt = now;
    }
    notifyListeners();
  }

  void setMqttConnected(bool value) {
    if (mqttConnected == value) {
      return;
    }
    mqttConnected = value;
    notifyListeners();
  }

  void markThresholdsSent(double t1, double t2) {
    pendingThresholds = (t1: t1, t2: t2);
    thresholdsSentAt = _clock();
    thresholdsConfirmedAt = null;
    notifyListeners();
  }

  // ส่งแล้วแต่อุปกรณ์ยังไม่รายงานค่าใหม่กลับมาเกินเวลาที่ควร
  bool get thresholdsAckOverdue {
    final sentAt = thresholdsSentAt;
    return pendingThresholds != null &&
        sentAt != null &&
        _clock().difference(sentAt) > const Duration(seconds: 15);
  }

  DateTime now() => _clock();

  // ล้างค่าสูงสุดเพื่อเริ่มการเป่าครั้งใหม่
  void resetPeak() {
    peakBac = null;
    peakAt = null;
    notifyListeners();
  }

  // ค่าที่จะใช้บันทึก: ค่าสูงสุดของรอบนี้ ถ้าไม่มีใช้ค่าปัจจุบัน
  double get measuredValue => peakBac ?? latest?.bac ?? 0.0;

  AlertStatus get measuredStatus => AlertStatusCode.fromLevel(
    alertLevelFor(measuredValue, threshold1, threshold2),
  );

  // ให้ UI คำนวณ "กี่วินาทีที่แล้ว" และสถานะ online/stale ใหม่
  void tick() => notifyListeners();
}
