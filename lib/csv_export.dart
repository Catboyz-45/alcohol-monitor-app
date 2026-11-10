import 'dart:ui' show Rect;

import 'csv_export_io.dart' if (dart.library.js_interop) 'csv_export_web.dart';

// บันทึก/แชร์ไฟล์ CSV ตามแพลตฟอร์ม
// เว็บ: ดาวน์โหลดไฟล์ทันที  มือถือ/macOS: เปิดหน้าแชร์ให้เลือกส่งต่อหรือบันทึกลงไฟล์
// shareOrigin: ตำแหน่งปุ่ม ใช้วาง popover บน iPad/macOS
Future<void> saveCsvFile({
  required String csv,
  required String fileName,
  Rect? shareOrigin,
}) =>
    savePlatformCsvFile(csv: csv, fileName: fileName, shareOrigin: shareOrigin);
