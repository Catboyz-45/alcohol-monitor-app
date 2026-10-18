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

// ปิดเลขบัตรให้เหลือ 3 หลักท้าย เช่น X-XXXX-XXXXX-12-3
String maskThaiId(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 13) {
    return digits.isEmpty ? '-' : 'X' * digits.length;
  }
  return 'X-XXXX-XXXXX-${digits.substring(10, 12)}-${digits[12]}';
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
