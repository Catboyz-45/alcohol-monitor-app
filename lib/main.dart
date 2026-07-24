import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'home_page.dart';

// จุดเริ่มต้นของแอป
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  // สร้าง Provider กลางและตั้งค่า theme ของแอป
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Alcohol Monitoring',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
        ),
        home: const HomePage(),
      ),
    );
  }
}
