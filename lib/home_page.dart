import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'home_service.dart';
import 'measurement_form_page.dart';
import 'measurement_history_page.dart';
import 'mqtt_service.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _mqttUser = String.fromEnvironment('APP_MQTT_USER');
  static const String _mqttPassword = String.fromEnvironment(
    'APP_MQTT_PASSWORD',
  );
  static const String _mqttClientIdDefine = String.fromEnvironment(
    'APP_MQTT_CLIENT_ID',
  );

  final HomeService _service = HomeService();
  MqttService? _mqttService;
  Timer? _pollingTimer;
  int _selectedIndex = 0;
  bool _isSending = false;

  @override
  // เริ่มต้นแอป: โหลดประวัติ, ต่อ MQTT, ดึงสถานะล่าสุด และเปิด polling
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.loadRecords();
      await _setupMqttRealtime();
      await _refreshDeviceStatus();
      // สำรองด้วยการดึง HTTP เป็นระยะ เผื่อ MQTT ขาดช่วง
      _startPolling();
    });
  }

  // ตั้งค่าและเชื่อมต่อ MQTT เพื่อรับข้อมูลแบบ real-time
  Future<void> _setupMqttRealtime() async {
    if (_mqttUser.isEmpty || _mqttPassword.isEmpty || !mounted) {
      return;
    }

    final generatedClientId =
        'flutter-${DateTime.now().millisecondsSinceEpoch}';
    final clientId =
        _mqttClientIdDefine.isEmpty ? generatedClientId : _mqttClientIdDefine;

    final appState = Provider.of<AppState>(context, listen: false);
    _mqttService = MqttService(
      clientId: clientId,
      username: _mqttUser,
      password: _mqttPassword,
      onConnectionChanged: appState.setConnection,
      onShadowUpdate: (update) {
        if (!mounted) {
          return;
        }
        // ส่งข้อมูลที่ได้จาก broker เข้า AppState โดยตรง
        appState.updateFromDevice(
          bac: update.bac,
          alertLevel: update.alertLevel,
          threshold1: update.threshold1,
          threshold2: update.threshold2,
          raw: update.raw,
        );
      },
    );

    await _mqttService!.connect();
  }

  // เริ่มจับเวลาเรียก refresh สถานะอุปกรณ์ซ้ำทุก 3 วินาที
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshDeviceStatus();
    });
  }

  @override
  // ปิด timer และตัดการเชื่อมต่อ MQTT ก่อนทำลายหน้า
  void dispose() {
    _pollingTimer?.cancel();
    _mqttService?.disconnect();
    super.dispose();
  }

  // ดึงสถานะอุปกรณ์ล่าสุดผ่าน HTTP แล้วอัปเดต AppState
  Future<void> _refreshDeviceStatus() async {
    if (_isSending || !mounted) {
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final status = await _service.getDeviceStatus();
      if (!mounted) {
        return;
      }

      appState.setConnection(true);
      // รวมข้อมูล threshold/bac/raw จากอุปกรณ์เข้า state กลาง
      appState.updateFromDevice(
        bac: status.bac,
        alertLevel: status.alertLevel,
        threshold1: status.threshold1,
        threshold2: status.threshold2,
        raw: status.raw,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      appState.setConnection(false);
    }
  }

  // ส่ง threshold จากแอปไปที่อุปกรณ์
  Future<void> _sendThresholds() async {
    if (_isSending || !mounted) {
      return;
    }

    _isSending = true;
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      await _service.updateThresholds(
        threshold1: appState.threshold.toDouble(),
        threshold2: appState.threshold2.toDouble(),
      );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('ส่งค่ามาตรฐานเรียบร้อย'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('ส่งค่าไม่สาเร็จ: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      _isSending = false;
    }
  }

  // สั่งเปิด/ปิด buzzer
  Future<void> _setBuzzer(bool value) async {
    try {
      await _service.setBinaryControl(field: 'buzzer', isOn: value);
    } catch (_) {}
  }

  // สั่งเปิด/ปิดไฟ LED สีแดง
  Future<void> _setLed(bool value) async {
    try {
      await _service.setBinaryControl(field: 'red', isOn: value);
    } catch (_) {}
  }

  @override
  // สร้างหน้าหลักและจัดการการสลับแท็บ
  Widget build(BuildContext context) {
    final pages = [
      const MeasurementFormPage(),
      const MeasurementHistoryPage(),
      SettingsPage(
        onSendThreshold: _sendThresholds,
        onSetBuzzer: _setBuzzer,
        onSetLed: _setLed,
        onReconnect: _refreshDeviceStatus,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Alcohol Monitoring System')),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            // เข้าแท็บประวัติเมื่อไร ให้รีโหลดข้อมูลล่าสุด
            Provider.of<AppState>(context, listen: false).loadRecords();
          }
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'วัดค่า',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'ประวัติ',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'ตั้งค่า',
          ),
        ],
      ),
    );
  }
}
