import 'dart:convert';

import 'package:alcohol_monitor_app/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ไม่ได้ตั้งค่า Firebase ใช้โหมดเก็บในเครื่อง', () async {
    final auth = AuthService(firebaseEnabled: false);
    await auth.restore();
    expect(auth.mode, AuthMode.localOnly);
  });

  test('เข้าสู่ระบบสำเร็จ แล้วเปิดแอปใหม่ยังอยู่ในระบบ', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('accounts:signInWithPassword')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'officer@example.com');
        return http.Response(
          jsonEncode({
            'idToken': 'id-1',
            'refreshToken': 'refresh-1',
            'expiresIn': '3600',
            'localId': 'uid-1',
            'email': 'officer@example.com',
          }),
          200,
        );
      }
      // securetoken refresh
      expect(request.bodyFields['refresh_token'], 'refresh-1');
      return http.Response(
        jsonEncode({
          'id_token': 'id-2',
          'refresh_token': 'refresh-2',
          'expires_in': '3600',
          'user_id': 'uid-1',
        }),
        200,
      );
    });

    final auth = AuthService(
      client: client,
      apiKey: 'k',
      firebaseEnabled: true,
    );
    await auth.restore();
    expect(auth.mode, AuthMode.signedOut);

    await auth.signIn(' officer@example.com ', 'secret');
    expect(auth.mode, AuthMode.signedIn);
    expect(auth.uid, 'uid-1');
    expect(await auth.idToken(), 'id-1');

    final reopened = AuthService(
      client: client,
      apiKey: 'k',
      firebaseEnabled: true,
    );
    await reopened.restore();
    expect(reopened.mode, AuthMode.signedIn);
    expect(await reopened.idToken(), 'id-2');
  });

  test('รหัสผิดได้ข้อความภาษาไทย', () async {
    final auth = AuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'INVALID_LOGIN_CREDENTIALS'},
          }),
          400,
        ),
      ),
      apiKey: 'k',
      firebaseEnabled: true,
    );
    await expectLater(
      auth.signIn('a@b.c', 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
        ),
      ),
    );
    expect(auth.mode, isNot(AuthMode.signedIn));
  });

  test('refresh token ใช้ไม่ได้แล้ว กลับไปหน้าเข้าสู่ระบบ', () async {
    SharedPreferences.setMockInitialValues({'auth_refresh_token': 'old'});
    final auth = AuthService(
      client: MockClient((_) async => http.Response('{}', 400)),
      apiKey: 'k',
      firebaseEnabled: true,
    );
    await auth.restore();
    expect(auth.mode, AuthMode.signedOut);
  });
}
