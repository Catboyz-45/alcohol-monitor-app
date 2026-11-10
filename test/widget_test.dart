import 'package:alcohol_monitor_app/auth_service.dart';
import 'package:alcohol_monitor_app/main.dart';
import 'package:alcohol_monitor_app/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ถอด widget ออกเพื่อหยุด timer ของอุปกรณ์จำลองก่อนจบเทสต์
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  // เปิดหน้าตรวจใหม่จากปุ่มบนหน้าหลัก
  Future<void> openFlow(WidgetTester tester) async {
    await tester.tap(find.text('เริ่มตรวจผู้ขับขี่'));
    await tester.pumpAndSettle();
    expect(find.text('ผู้ถูกตรวจเป็นใคร'), findsOneWidget);
  }

  Future<void> blow(WidgetTester tester) async {
    await tester.tap(find.text('จำลองการเป่า'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('ไม่ได้ตั้งค่าอะไรเลย เปิดเป็นโหมดสาธิตพร้อมอุปกรณ์จำลอง', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MyApp(auth: AuthService(firebaseEnabled: false)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ด่านตรวจวันนี้'), findsOneWidget);
    expect(find.text('โหมดสาธิต'), findsOneWidget);
    expect(find.text('เครื่องวัดพร้อมใช้งาน'), findsOneWidget);

    // เป่าก่อนแล้วค่อยกรอกข้อมูลได้ และแอปจำค่าสูงสุดไว้
    await openFlow(tester);
    await tester.tap(find.text('ให้เป่าก่อน แล้วค่อยกรอก'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ยังไม่พบการเป่า'), findsOneWidget);
    await blow(tester);
    expect(find.text('ค่าสูงสุดของการเป่านี้'), findsOneWidget);

    // ดูผลได้ แต่บันทึกไม่ได้จนกว่าจะกรอกข้อมูลครบ
    await tester.tap(find.text('ใช้ค่านี้ ดูผล'));
    await tester.pumpAndSettle();
    expect(find.text('ขั้นที่ 3 จาก 3'), findsOneWidget);
    await tester.tap(find.text('บันทึกผลตรวจ'));
    await tester.pumpAndSettle();
    expect(find.text('ผู้ถูกตรวจเป็นใคร'), findsOneWidget);
    expect(find.text('กรุณากรอกชื่อ-นามสกุล'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('ฟอร์มไม่ยอมรับเลขบัตรที่ checksum ผิด', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MyApp(auth: AuthService(firebaseEnabled: false)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await openFlow(tester);

    await tester.enterText(
      find.widgetWithText(LabeledField, 'เลขบัตรประชาชน').last,
      '1101700203451',
    );
    await tester.tap(find.text('ถัดไป: ให้เป่า'));
    await tester.pump();

    expect(
      find.text('เลขบัตรประชาชนไม่ถูกต้อง (หลักตรวจสอบไม่ตรง)'),
      findsOneWidget,
    );
    expect(find.text('กรุณากรอกชื่อ-นามสกุล'), findsOneWidget);
    expect(find.text('กรุณาเลือกจังหวัด'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('ตรวจครบ 3 ขั้นแล้วบันทึก ขึ้นในประวัติแบบปิดเลขบัตร', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MyApp(auth: AuthService(firebaseEnabled: false)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await openFlow(tester);

    Finder field(String label) => find.descendant(
      of: find.widgetWithText(LabeledField, label),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field('ชื่อ-นามสกุล'), 'สมชาย ใจดี');
    await tester.enterText(field('เลขบัตรประชาชน'), '1101700203450');
    await tester.pump();
    expect(find.text('เลขถูกต้อง (ตรวจหลักสุดท้ายแล้ว)'), findsOneWidget);
    await tester.enterText(field('อายุ'), '35');
    await tester.enterText(field('ทะเบียนรถ'), '1กก 1234');

    // จังหวัด: เลือกจากรายการที่ค้นหาได้
    await tester.tap(find.text('เลือกจังหวัด'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'กรุงเทพ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('กรุงเทพมหานคร').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ถัดไป: ให้เป่า'));
    await tester.pumpAndSettle();
    expect(find.text('ขั้นที่ 2 จาก 3'), findsOneWidget);
    await blow(tester);
    await tester.tap(find.text('ใช้ค่านี้ ดูผล'));
    await tester.pumpAndSettle();
    expect(find.text('X-XXXX-XXXXX-45-0'), findsOneWidget);

    await tester.tap(find.text('บันทึกผลตรวจ'));
    await tester.pumpAndSettle();
    expect(find.text('บันทึกผลตรวจแล้ว'), findsOneWidget);
    expect(find.text('สมชาย ใจดี'), findsOneWidget);

    await tester.tap(find.text('ประวัติ').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('สมชาย ใจดี'), findsOneWidget);
    expect(find.text('ส่งออก CSV'), findsOneWidget);

    // กรองช่วง "วันนี้" แล้วยังเห็นอยู่
    await tester.tap(find.text('วันนี้'));
    await tester.pump();
    expect(find.text('สมชาย ใจดี'), findsOneWidget);

    await tester.tap(find.text('สมชาย ใจดี'));
    await tester.pumpAndSettle();
    expect(find.text('X-XXXX-XXXXX-45-0'), findsOneWidget);
    expect(find.text('1-1017-00203-45-0'), findsNothing);

    await tester.tap(find.byTooltip('แสดงเลขบัตร'));
    await tester.pump();
    expect(find.text('1-1017-00203-45-0'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'มี Firebase แต่ยังไม่เข้าสู่ระบบ แสดงหน้า login และเข้าโหมดสาธิตได้',
    (tester) async {
      final auth = AuthService(
        firebaseEnabled: true,
        apiKey: 'k',
        client: MockClient((_) async => http.Response('{}', 400)),
      );
      await tester.pumpWidget(MyApp(auth: auth));
      await tester.pump();

      expect(find.text('เข้าสู่ระบบ'), findsOneWidget);

      await tester.tap(find.text('เข้าสู่ระบบ'));
      await tester.pump();
      expect(find.text('กรุณากรอกอีเมลให้ถูกต้อง'), findsOneWidget);

      await tester.ensureVisible(find.text('ทดลองใช้โหมดสาธิต'));
      await tester.tap(find.text('ทดลองใช้โหมดสาธิต'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('ด่านตรวจวันนี้'), findsOneWidget);
      await unmount(tester);
    },
  );
}
