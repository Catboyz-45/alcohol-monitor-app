import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'config.dart';
import 'device_link.dart';
import 'firestore_repository.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'theme.dart';

// จุดเริ่มต้นของแอป
void main() {
  runApp(MyApp(auth: AuthService()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.auth});

  final AuthService auth;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    widget.auth.restore();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.auth,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Alcohol Monitor',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const AuthGate(),
      ),
    );
  }
}

// เลือกหน้าตามสถานะการเข้าสู่ระบบ
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    switch (auth.mode) {
      case AuthMode.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthMode.signedOut:
        return const LoginPage();
      case AuthMode.signedIn:
      case AuthMode.demo:
      case AuthMode.localOnly:
        // key เปลี่ยนเมื่อเปลี่ยนบัญชี/โหมด เพื่อสร้าง state ใหม่ ไม่ให้ข้อมูลปนกัน
        return SessionScope(
          key: ValueKey('${auth.mode}-${auth.uid}'),
          auth: auth,
        );
    }
  }
}

// สร้าง AppState และช่องทางคุยกับอุปกรณ์ของ session ปัจจุบัน
class SessionScope extends StatefulWidget {
  const SessionScope({super.key, required this.auth});

  final AuthService auth;

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  late final AppState _state;
  late final DeviceLink _link;

  @override
  void initState() {
    super.initState();
    final auth = widget.auth;
    // โหมดสาธิต หรือยังไม่ได้ตั้งค่าอุปกรณ์ → ใช้อุปกรณ์จำลอง
    // ข้อมูลโหมดสาธิตเก็บแยก key และไม่ส่งขึ้น cloud
    final demo = auth.mode == AuthMode.demo;
    final simulated = demo || !AppConfig.hasDevice;
    _state = AppState(
      remote:
          auth.mode == AuthMode.signedIn
              ? FirestoreRepository(idToken: auth.idToken, uid: auth.uid ?? '')
              : null,
      storageKey: demo ? 'demo_measurement_records' : 'measurement_records',
      isDemo: simulated,
    );
    _link = simulated ? SimulatedDeviceLink(_state) : NetpieDeviceLink(_state);
    _link.start();
    _state.loadRecords();
  }

  @override
  void dispose() {
    _link.stop();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _state),
        Provider<DeviceLink>.value(value: _link),
      ],
      child: const HomePage(),
    );
  }
}
