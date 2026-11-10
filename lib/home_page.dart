import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'dashboard_page.dart';
import 'device_link.dart';
import 'measure_flow_page.dart';
import 'measurement_history_page.dart';
import 'settings_page.dart';

// โครงหลักของแอป: 3 แท็บ (หน้าหลัก / ประวัติ / เครื่องวัด)
// การตรวจแต่ละครั้งเปิดเป็นหน้าเต็มจอแยก (MeasureFlowPage)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _select(int index) {
    if (index == 1) {
      // เข้าแท็บประวัติเมื่อไร ให้ซิงก์ข้อมูลล่าสุด
      context.read<AppState>().syncNow();
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> _startMeasurement() async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.of(context).push<MeasureFlowResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => MultiProvider(
              // หน้าใหม่อยู่นอก Provider ของ SessionScope จึงต้องส่งต่อ
              providers: [
                ChangeNotifierProvider.value(value: context.read<AppState>()),
                Provider<DeviceLink>.value(value: context.read<DeviceLink>()),
              ],
              child: const MeasureFlowPage(),
            ),
      ),
    );
    if (saved == null || !mounted) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            saved.synced
                ? 'บันทึกผลตรวจแล้ว'
                : 'บันทึกในเครื่องแล้ว จะส่งขึ้น cloud เมื่อเชื่อมต่อได้',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        // IndexedStack เก็บตำแหน่งเลื่อนและตัวกรองของแต่ละแท็บไว้
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            DashboardPage(
              onStartMeasurement: _startMeasurement,
              onOpenHistory: () => _select(1),
              onOpenDevice: () => _select(2),
            ),
            const MeasurementHistoryPage(),
            const SettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'หน้าหลัก',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'ประวัติ',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory_rounded),
            label: 'เครื่องวัด',
          ),
        ],
      ),
    );
  }
}
