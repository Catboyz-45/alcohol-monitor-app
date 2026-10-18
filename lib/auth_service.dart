import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

enum AuthMode {
  // กำลังโหลด session เดิมจากเครื่อง
  loading,
  // ยังไม่ได้เข้าสู่ระบบ (มี Firebase แต่ยังไม่ login)
  signedOut,
  // เข้าสู่ระบบด้วยบัญชีเจ้าหน้าที่แล้ว ข้อมูลซิงก์กับ Firestore
  signedIn,
  // โหมดสาธิต: อุปกรณ์จำลอง เก็บข้อมูลเฉพาะในเครื่อง
  demo,
  // ไม่ได้ตั้งค่า Firebase: ใช้อุปกรณ์จริงได้ แต่เก็บประวัติในเครื่องเท่านั้น
  localOnly,
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

// เข้าสู่ระบบด้วย Firebase Authentication ผ่าน REST API
// ได้ ID token ไปแนบกับทุกคำขอ Firestore เพื่อให้ Security Rules ตรวจสิทธิ์ได้
class AuthService extends ChangeNotifier {
  AuthService({
    http.Client? client,
    String apiKey = AppConfig.firebaseApiKey,
    bool? firebaseEnabled,
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey,
       _firebaseEnabled = firebaseEnabled ?? AppConfig.hasFirebase;

  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _emailKey = 'auth_email';

  final http.Client _client;
  final String _apiKey;
  final bool _firebaseEnabled;

  AuthMode mode = AuthMode.loading;
  String? email;
  String? uid;
  String? _idToken;
  String? _refreshToken;
  DateTime? _expiresAt;

  bool get firebaseEnabled => _firebaseEnabled;

  // โหลด session เดิม ถ้ามี refresh token ให้ขอ ID token ใหม่
  Future<void> restore() async {
    if (!_firebaseEnabled) {
      _setMode(AuthMode.localOnly);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _refreshToken = prefs.getString(_refreshTokenKey);
    email = prefs.getString(_emailKey);
    if (_refreshToken == null) {
      _setMode(AuthMode.signedOut);
      return;
    }
    try {
      await _refresh();
      _setMode(AuthMode.signedIn);
    } catch (_) {
      await _clearSession();
      _setMode(AuthMode.signedOut);
    }
  }

  Future<void> signIn(String email, String password) async {
    final response = await _client.post(
      Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_apiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );
    final body = _decode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw AuthException(_describeError(body));
    }

    _idToken = body['idToken'] as String?;
    _refreshToken = body['refreshToken'] as String?;
    uid = body['localId'] as String?;
    this.email = body['email'] as String? ?? email.trim();
    _expiresAt = _expiryFrom(body['expiresIn']);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, _refreshToken ?? '');
    await prefs.setString(_emailKey, this.email ?? '');
    _setMode(AuthMode.signedIn);
  }

  void enterDemo() => _setMode(AuthMode.demo);

  Future<void> signOut() async {
    await _clearSession();
    _setMode(_firebaseEnabled ? AuthMode.signedOut : AuthMode.localOnly);
  }

  // คืน ID token ที่ยังไม่หมดอายุ (ต่ออายุให้อัตโนมัติก่อนหมด 1 นาที)
  Future<String> idToken() async {
    final expiresAt = _expiresAt;
    if (_idToken == null ||
        expiresAt == null ||
        DateTime.now().isAfter(
          expiresAt.subtract(const Duration(minutes: 1)),
        )) {
      await _refresh();
    }
    return _idToken!;
  }

  Future<void> _refresh() async {
    final token = _refreshToken;
    if (token == null || token.isEmpty) {
      throw AuthException('กรุณาเข้าสู่ระบบใหม่');
    }
    final response = await _client.post(
      Uri.parse('https://securetoken.googleapis.com/v1/token?key=$_apiKey'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'grant_type': 'refresh_token', 'refresh_token': token},
    );
    final body = _decode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw AuthException(_describeError(body));
    }
    _idToken = body['id_token'] as String?;
    _refreshToken = body['refresh_token'] as String? ?? token;
    uid = body['user_id'] as String? ?? uid;
    _expiresAt = _expiryFrom(body['expires_in']);
  }

  Future<void> _clearSession() async {
    _idToken = null;
    _refreshToken = null;
    _expiresAt = null;
    uid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshTokenKey);
  }

  void _setMode(AuthMode value) {
    mode = value;
    notifyListeners();
  }

  static DateTime _expiryFrom(Object? seconds) {
    final value = int.tryParse(seconds?.toString() ?? '') ?? 3600;
    return DateTime.now().add(Duration(seconds: value));
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  // แปลง error code ของ Firebase Auth เป็นข้อความภาษาไทย
  static String _describeError(Map<String, dynamic> body) {
    final error = body['error'];
    final message =
        error is Map ? error['message']?.toString() ?? '' : error?.toString();
    switch (message?.split(' ').first) {
      case 'INVALID_LOGIN_CREDENTIALS':
      case 'INVALID_PASSWORD':
      case 'EMAIL_NOT_FOUND':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'INVALID_EMAIL':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'USER_DISABLED':
        return 'บัญชีนี้ถูกระงับการใช้งาน';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'ลองผิดหลายครั้งเกินไป กรุณารอสักครู่';
      case 'TOKEN_EXPIRED':
      case 'INVALID_REFRESH_TOKEN':
        return 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่';
      default:
        return 'เข้าสู่ระบบไม่สำเร็จ${message == null || message.isEmpty ? '' : ' ($message)'}';
    }
  }
}
