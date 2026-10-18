import 'device_reading.dart';

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

  // true เมื่อส่งขึ้น cloud สำเร็จแล้ว (เก็บเฉพาะในเครื่อง ไม่ส่งขึ้น Firestore)
  final bool synced;

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
    this.synced = false,
  });

  AlertStatus get alertStatus => AlertStatusCode.fromCode(status);

  MeasurementRecord copyWith({bool? synced}) {
    return MeasurementRecord(
      id: id,
      name: name,
      idCard: idCard,
      age: age,
      licensePlate: licensePlate,
      province: province,
      alcoholValue: alcoholValue,
      status: status,
      timestamp: timestamp,
      synced: synced ?? this.synced,
    );
  }

  // แปลงโมเดลเป็น JSON เพื่อเก็บ local
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
      'synced': synced,
    };
  }

  // สร้างโมเดลจาก JSON โดยมีค่า fallback กันข้อมูลไม่ครบ
  // ข้อมูลรุ่นเก่าไม่มี synced ถือว่าซิงก์แล้ว เพราะรุ่นเก่าโหลดทับจาก cloud เสมอ
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
          DateTime.fromMillisecondsSinceEpoch(0),
      synced: json['synced'] as bool? ?? true,
    );
  }
}
