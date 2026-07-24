import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';

class MeasurementHistoryPage extends StatelessWidget {
  const MeasurementHistoryPage({super.key});

  @override
  // แสดงรายการประวัติทั้งหมดและปุ่มรีเฟรชข้อมูล
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final records = appState.records;
        final total = records.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ประวัติการวัดค่า',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      // ดึงประวัติล่าสุดจาก cloud/local ใหม่อีกครั้ง
                      await appState.loadRecords();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('รีเฟรชประวัติแล้ว'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('รีเฟรชประวัติ'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'จำนวนทั้งหมด: $total รายการ',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              if (records.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      const Icon(
                        Icons.history,
                        size: 80,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ยังไม่มีประวัติการวัดค่า',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ไปที่แท็บวัดค่าเพื่อบันทึกข้อมูล',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];

                    Color statusColor;
                    IconData iconData;
                    String displayStatus = record.status;

                    // แปลงสถานะที่อาจหลากหลายให้เหลือชุดเดียวเพื่อแสดงผล
                    switch (record.status.toUpperCase()) {
                      case 'SAFE':
                      case 'SOBER':
                        statusColor = Colors.greenAccent;
                        iconData = Icons.check_circle;
                        displayStatus = 'SAFE';
                        break;
                      case 'WARNING':
                        statusColor = Colors.yellowAccent;
                        iconData = Icons.error_outline;
                        displayStatus = 'WARNING';
                        break;
                      case 'DRUNK':
                        statusColor = Colors.redAccent;
                        iconData = Icons.warning_rounded;
                        displayStatus = 'DRUNK';
                        break;
                      default:
                        statusColor = Colors.greenAccent;
                        iconData = Icons.check_circle;
                        displayStatus = 'SAFE';
                    }

                    return Card(
                      color: Colors.black,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                iconData,
                                color: statusColor,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'บัตรปชช: ${record.idCard} | อายุ: ${record.age} ปี',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ทะเบียน: ${record.licensePlate} | ${record.province}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ค่าที่วัดได้: ${record.alcoholValue.toStringAsFixed(1)} | สถานะ: $displayStatus',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: statusColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDateTime(record.timestamp),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  displayStatus,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  // กดลบแล้วเปิด dialog ยืนยันก่อนทุกครั้ง
                                  onPressed:
                                      () => _confirmDelete(
                                        context,
                                        appState,
                                        record,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // แสดงกล่องยืนยันก่อนลบ และแจ้งผลลบสำเร็จ/ไม่สำเร็จ
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    AppState appState,
    MeasurementRecord record,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('ยืนยันการลบ'),
            content: Text('ต้องการลบข้อมูลของ ${record.name} หรือไม่?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  try {
                    // ลบจาก state (และพยายามลบที่ cloud) ตาม id
                    await appState.removeRecord(record.id);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('ลบข้อมูลสาเร็จ'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                    }
                  } catch (e) {
                    if (context.mounted) {
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
                },
                child: const Text('ลบ', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  // ฟอร์แมตวันที่ภาษาไทยแบบอ่านเร็ว
  String _formatDateTime(DateTime dateTime) {
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];

    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} '
        'เวลา ${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
