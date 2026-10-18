import 'package:alcohol_monitor_app/thai_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // เลขตัวอย่างที่คำนวณ checksum แล้ว (ไม่ใช่ของบุคคลจริง)
  const validId = '1101700203450';

  test('ยอมรับเลขที่ checksum ถูกต้อง', () {
    expect(isValidThaiId(validId), isTrue);
    expect(isValidThaiId('1-1017-00203-45-0'), isTrue);
  });

  test('ปฏิเสธเลขที่หลักตรวจสอบผิด ความยาวผิด หรือมีตัวอักษร', () {
    expect(isValidThaiId('1101700203451'), isFalse);
    expect(isValidThaiId('110170020345'), isFalse);
    expect(isValidThaiId('11017002034500'), isFalse);
    expect(isValidThaiId('11017002034a0'), isFalse);
    expect(isValidThaiId(''), isFalse);
  });

  test('ปิดเลขบัตรเหลือ 3 หลักท้าย', () {
    expect(maskThaiId(validId), 'X-XXXX-XXXXX-45-0');
    expect(maskThaiId(''), '-');
  });

  test('จัดรูปแบบเลขบัตรเต็ม', () {
    expect(formatThaiId(validId), '1-1017-00203-45-0');
    expect(formatThaiId('123'), '123');
  });
}
