import 'package:alcohol_monitor_app/auth_service.dart';
import 'package:alcohol_monitor_app/main.dart';
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

  testWidgets('ไม่ได้ตั้งค่าอะไรเลย เปิดเป็นโหมดสาธิตพร้อมอุปกรณ์จำลอง', (
    tester,
  ) async {
    await tester.pumpWidget(MyApp(auth: AuthService(firebaseEnabled: false)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ผลการเป่า'), findsOneWidget);
    expect(find.textContaining('โหมดสาธิต'), findsOneWidget);
    expect(find.text('อุปกรณ์ออนไลน์'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('ฟอร์มไม่ยอมรับเลขบัตรที่ checksum ผิด', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MyApp(auth: AuthService(firebaseEnabled: false)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'เลขบัตรประชาชน'),
      '1101700203451',
    );
    await tester.tap(find.text('บันทึกผลตรวจ'));
    await tester.pump();

    expect(
      find.text('เลขบัตรประชาชนไม่ถูกต้อง (หลักตรวจสอบไม่ตรง)'),
      findsOneWidget,
    );
    expect(find.text('กรุณากรอกชื่อ-นามสกุล'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('บันทึกผลตรวจแล้วขึ้นในแท็บประวัติแบบปิดเลขบัตร', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MyApp(auth: AuthService(firebaseEnabled: false)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'ชื่อ-นามสกุล'),
      'สมชาย ใจดี',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'เลขบัตรประชาชน'),
      '1101700203450',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'อายุ'), '35');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ทะเบียนรถ'),
      '1กก 1234',
    );
    await tester.tap(find.text('จังหวัดของทะเบียนรถ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('กรุงเทพมหานคร').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('บันทึกผลตรวจ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('บันทึกข้อมูลสำเร็จ'), findsOneWidget);

    await tester.tap(find.text('ประวัติ').last);
    await tester.pump(const Duration(milliseconds: 500));
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

      await tester.tap(find.text('ทดลองใช้โหมดสาธิต'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('ผลการเป่า'), findsOneWidget);
      await unmount(tester);
    },
  );
}
