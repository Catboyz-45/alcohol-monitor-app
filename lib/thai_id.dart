// ตรวจเลขบัตรประชาชนไทย 13 หลักด้วย checksum (mod 11)
bool isValidThaiId(String input) {
  final digits = input.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^\d{13}$').hasMatch(digits)) {
    return false;
  }

  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(digits[i]) * (13 - i);
  }
  final check = (11 - sum % 11) % 10;
  return check == int.parse(digits[12]);
}

// เลขบัตรที่เก็บในเครื่องแบบปิดไว้ (เหลือ 3 หลักท้าย) เช่น XXXXXXXXXX123
String redactIdForStorage(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 13) {
    return input;
  }
  return 'XXXXXXXXXX${digits.substring(10)}';
}

// true ถ้ามีเลขบัตรเต็ม (ไม่ใช่แบบที่ปิดไว้ตอนเก็บในเครื่อง)
bool hasFullThaiId(String input) =>
    RegExp(r'^\d{13}$').hasMatch(input.replaceAll(RegExp(r'[\s-]'), ''));

// ปิดเลขบัตรให้เหลือ 3 หลักท้าย เช่น X-XXXX-XXXXX-12-3
String maskThaiId(String input) {
  final chars = input.replaceAll(RegExp(r'[^0-9X]'), '');
  if (chars.length != 13) {
    return chars.isEmpty ? '-' : 'X' * chars.length;
  }
  return 'X-XXXX-XXXXX-${chars.substring(10, 12)}-${chars[12]}';
}

// จัดรูปแบบเลขบัตรเต็มให้อ่านง่าย เช่น 1-2345-67890-12-3
String formatThaiId(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 13) {
    return input;
  }
  return '${digits[0]}-${digits.substring(1, 5)}-${digits.substring(5, 10)}-'
      '${digits.substring(10, 12)}-${digits[12]}';
}
