import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';

class MeasurementFormPage extends StatefulWidget {
  const MeasurementFormPage({super.key});

  @override
  State<MeasurementFormPage> createState() => _MeasurementFormPageState();
}

class _MeasurementFormPageState extends State<MeasurementFormPage> {
  static const List<String> _centralProvinces = [
    'กรุงเทพมหานคร',
    'นนทบุรี',
    'ปทุมธานี',
    'สมุทรปราการ',
    'พระนครศรีอยุธยา',
    'อ่างทอง',
    'ลพบุรี',
    'สิงห์บุรี',
    'ชัยนาท',
    'สระบุรี',
    'นครนายก',
    'สุพรรณบุรี',
    'นครปฐม',
    'สมุทรสาคร',
    'สมุทรสงคราม',
    'ราชบุรี',
    'กาญจนบุรี',
    'เพชรบุรี',
    'ประจวบคีรีขันธ์',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idCardController = TextEditingController();
  final _ageController = TextEditingController();
  final _licensePlateController = TextEditingController();
  String? _selectedProvince;

  // คำนวณค่าที่จะแสดงบนจอจากค่าบอร์ดล่าสุด
  ({double shownValue, String shownStatus}) _computeShownMeasurement(
    AppState appState,
  ) {
    final currentBac = appState.latestBoardAlcohol ?? appState.alcohol;
    // กรอง noise: ค่าต่ำมากให้แสดงเป็น 0
    final shownValue = currentBac < 10 ? 0.0 : currentBac;

    final shownStatus =
        shownValue >= appState.threshold2
            ? 'DRUNK'
            : shownValue >= appState.threshold
            ? 'WARNING'
            : 'SAFE';

    return (shownValue: shownValue, shownStatus: shownStatus);
  }

  @override
  // คืนทรัพยากรของ TextEditingController ทุกตัว
  void dispose() {
    _nameController.dispose();
    _idCardController.dispose();
    _ageController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  // ตรวจฟอร์มและบันทึกข้อมูลผู้เป่าพร้อมผลวัด
  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    final shown = _computeShownMeasurement(appState);
    // ใช้ timestamp เป็น id เพื่อให้ไม่ซ้ำง่าย
    final record = MeasurementRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      idCard: _idCardController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      licensePlate: _licensePlateController.text.trim(),
      province: _selectedProvince ?? '',
      alcoholValue: shown.shownValue,
      status: shown.shownStatus,
      timestamp: DateTime.now(),
    );

    try {
      await appState.addRecord(record);

      _nameController.clear();
      _idCardController.clear();
      _ageController.clear();
      _licensePlateController.clear();
      setState(() {
        _selectedProvince = null;
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('บันทึกข้อมูลสาเร็จ'),
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
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  // สร้างหน้าแบบฟอร์มและการ์ดสถานะการวัด
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final shown = _computeShownMeasurement(appState);
        final displayValue = shown.shownValue;
        Color statusColor;
        final statusDisplay = shown.shownStatus;

        if (statusDisplay == 'DRUNK') {
          statusColor = Colors.redAccent;
        } else if (statusDisplay == 'WARNING') {
          statusColor = Colors.yellowAccent;
        } else {
          statusColor = Colors.greenAccent;
        }

        IconData iconData;
        switch (statusDisplay) {
          case 'DRUNK':
            iconData = Icons.warning_rounded;
            break;
          case 'WARNING':
            iconData = Icons.error_outline;
            break;
          default:
            iconData = Icons.check_circle;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        Text(
                          'การวัดค่าแอลกอฮอล์',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          tooltip: 'รีเซ็ตค่า',
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            // ล้างค่าการวัดบนหน้าจอทันที
                            Provider.of<AppState>(
                              context,
                              listen: false,
                            ).resetAlcohol();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Icon(iconData, size: 76, color: statusColor),
                    const SizedBox(height: 12),
                    Text(
                      statusDisplay,
                      style: TextStyle(
                        fontSize: 24,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ค่าที่ได้: ${appState.latestBoardAlcohol == null ? '-' : displayValue.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildThresholdBadge(
                          label: 'เกณฑ์ 1',
                          value: appState.threshold,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 12),
                        _buildThresholdBadge(
                          label: 'เกณฑ์ 2',
                          value: appState.threshold2,
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      appState.lastUpdate == null
                          ? 'อัปเดตล่าสุด: -'
                          : 'อัปเดตล่าสุด: ${_formatDateTime(appState.lastUpdate!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'บันทึกข้อมูลผู้เป่า',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อ-นามสกุล',
                          hintText: 'กรอกชื่อ-นามสกุลผู้เป่า',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'กรุณากรอกชื่อ-นามสกุล';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _idCardController,
                        decoration: const InputDecoration(
                          labelText: 'เลขบัตรประชาชน',
                          hintText: 'กรอกเลขบัตรประชาชน 13 หลัก',
                          prefixIcon: Icon(Icons.credit_card),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 13,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'กรุณากรอกเลขบัตรประชาชน';
                          }
                          // บัตรประชาชนไทยต้องยาว 13 หลัก
                          if (value.trim().length != 13) {
                            return 'เลขบัตรประชาชนต้องมี 13 หลัก';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ageController,
                        decoration: const InputDecoration(
                          labelText: 'อายุ',
                          hintText: 'กรอกอายุ',
                          prefixIcon: Icon(Icons.cake),
                          border: OutlineInputBorder(),
                          suffixText: 'ปี',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'กรุณากรอกอายุ';
                          }
                          final age = int.tryParse(value.trim());
                          if (age == null || age < 1 || age > 120) {
                            return 'กรุณากรอกอายุที่ถูกต้อง (1-120)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _licensePlateController,
                        decoration: const InputDecoration(
                          labelText: 'ทะเบียนรถ',
                          hintText: 'กรอกทะเบียนรถ เช่น กก 1234',
                          prefixIcon: Icon(Icons.directions_car),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'กรุณากรอกทะเบียนรถ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedProvince,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'จังหวัด',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                        items:
                            _centralProvinces
                                .map(
                                  (province) => DropdownMenuItem<String>(
                                    value: province,
                                    child: Text(province),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedProvince = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณาเลือกจังหวัด';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _saveRecord,
                          icon: const Icon(Icons.save),
                          label: const Text(
                            'บันทึกข้อมูล',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'สถานะการเชื่อมต่อ MQTT',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: appState.connected ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        appState.connected
                            ? 'เชื่อมต่อแล้ว'
                            : 'ไม่ได้เชื่อมต่อ',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // การ์ดพื้นฐานของหน้านี้ เพื่อให้สไตล์เหมือนกันทุก section
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  // ป้ายแสดงค่า threshold แบบย่อ
  Widget _buildThresholdBadge({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ฟอร์แมตเวลาให้อ่านง่ายในหน้า UI
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
