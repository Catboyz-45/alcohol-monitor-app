import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'measurement_form_page.dart';
import 'measurement_history_page.dart';
import 'settings_page.dart';
import 'widgets/common.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const _titles = ['ตรวจวัด', 'ประวัติ', 'อุปกรณ์'];

  @override
  // สร้างหน้าหลักและจัดการการสลับแท็บ
  Widget build(BuildContext context) {
    final link = context.select<AppState, LinkState>((s) => s.link);
    final isDemo = context.select<AppState, bool>((s) => s.isDemo);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LinkChip(
              link: link,
              onTap: () => setState(() => _selectedIndex = 2),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isDemo) const _DemoBanner(),
          // IndexedStack เก็บข้อความที่กรอกในฟอร์มไว้ แม้สลับไปแท็บอื่น
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                MeasurementFormPage(),
                MeasurementHistoryPage(),
                SettingsPage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            // เข้าแท็บประวัติเมื่อไร ให้ซิงก์ข้อมูลล่าสุด
            context.read<AppState>().syncNow();
          }
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.air_outlined),
            selectedIcon: Icon(Icons.air),
            label: 'ตรวจวัด',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'ประวัติ',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory),
            label: 'อุปกรณ์',
          ),
        ],
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            size: 18,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'โหมดสาธิต: ค่าจากอุปกรณ์จำลอง ไม่ใช่ผลตรวจจริง',
              style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
