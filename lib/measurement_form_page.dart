import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'device_link.dart';
import 'device_reading.dart';
import 'provinces.dart';
import 'thai_id.dart';
import 'theme.dart';
import 'widgets/common.dart';

class MeasurementFormPage extends StatefulWidget {
  const MeasurementFormPage({super.key});

  @override
  State<MeasurementFormPage> createState() => _MeasurementFormPageState();
}

class _MeasurementFormPageState extends State<MeasurementFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idCardController = TextEditingController();
  final _ageController = TextEditingController();
  final _licensePlateController = TextEditingController();
  String? _selectedProvince;
  bool _saving = false;

  @override
  // คืนทรัพยากรของ TextEditingController ทุกตัว
  void dispose() {
    _nameController.dispose();
    _idCardController.dispose();
    _ageController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  // ตรวจฟอร์มและบันทึกข้อมูลผู้เป่าพร้อมผลวัด
  Future<void> _saveRecord() async {
    final appState = context.read<AppState>();
    if (appState.latest == null) {
      _showSnack('ยังไม่มีค่าจากอุปกรณ์ กรุณาตรวจการเชื่อมต่อก่อนบันทึก');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();
    final record = MeasurementRecord(
      // ใช้เวลาระดับไมโครวินาทีเป็น id เพื่อลดโอกาสชนกันเมื่อหลายเครื่องบันทึกพร้อมกัน
      id: '${now.millisecondsSinceEpoch}-${now.microsecond}',
      name: _nameController.text.trim(),
      idCard: _idCardController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      licensePlate: _licensePlateController.text.trim(),
      province: _selectedProvince ?? '',
      alcoholValue: double.parse(appState.measuredValue.toStringAsFixed(1)),
      status: appState.measuredStatus.code,
      timestamp: now,
    );

    setState(() => _saving = true);
    await appState.addRecord(record);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _selectedProvince = null;
    });
    _formKey.currentState!.reset();
    _nameController.clear();
    _idCardController.clear();
    _ageController.clear();
    _licensePlateController.clear();
    appState.resetPeak();

    final synced =
        !appState.hasCloud ||
        appState.records.any((r) => r.id == record.id && r.synced);
    _showSnack(
      synced
          ? 'บันทึกข้อมูลสำเร็จ'
          : 'บันทึกในเครื่องแล้ว จะส่งขึ้น cloud อัตโนมัติเมื่อเชื่อมต่อได้',
      color: synced ? AlertStatus.safe.color : AlertStatus.warning.color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        const _ReadingCard(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle(
                    'ข้อมูลผู้รับการตรวจ',
                    subtitle: 'บันทึกพร้อมค่าสูงสุดของการเป่ารอบนี้',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อ-นามสกุล',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'กรุณากรอกชื่อ-นามสกุล'
                                : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _idCardController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(13),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'เลขบัตรประชาชน',
                      hintText: '13 หลัก',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'กรุณากรอกเลขบัตรประชาชน';
                      }
                      if (text.length != 13) {
                        return 'เลขบัตรประชาชนต้องมี 13 หลัก';
                      }
                      if (!isValidThaiId(text)) {
                        return 'เลขบัตรประชาชนไม่ถูกต้อง (หลักตรวจสอบไม่ตรง)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'อายุ',
                      prefixIcon: Icon(Icons.cake_outlined),
                      suffixText: 'ปี',
                    ),
                    validator: (value) {
                      final age = int.tryParse(value?.trim() ?? '');
                      if (age == null || age < 1 || age > 120) {
                        return 'กรุณากรอกอายุที่ถูกต้อง (1-120)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _licensePlateController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'ทะเบียนรถ',
                      hintText: 'เช่น 1กก 1234',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                    ),
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'กรุณากรอกทะเบียนรถ'
                                : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProvince,
                    isExpanded: true,
                    menuMaxHeight: 360,
                    decoration: const InputDecoration(
                      labelText: 'จังหวัดของทะเบียนรถ',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: [
                      for (final province in thaiProvinces)
                        DropdownMenuItem(
                          value: province,
                          child: Text(province),
                        ),
                    ],
                    onChanged:
                        (value) => setState(() => _selectedProvince = value),
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'กรุณาเลือกจังหวัด'
                                : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveRecord,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'กำลังบันทึก…' : 'บันทึกผลตรวจ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// การ์ดแสดงผลการเป่า: ค่าสูงสุดของรอบนี้ + ค่าสดจากบอร์ด
class _ReadingCard extends StatelessWidget {
  const _ReadingCard();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final latest = appState.latest;
    final status = appState.measuredStatus;
    final hasPeak = appState.peakBac != null;
    final link = appState.link;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              'ผลการเป่า',
              subtitle:
                  hasPeak
                      ? 'ค่าสูงสุดของรอบนี้ · ${timeAgo(appState.peakAt, now: appState.now())}'
                      : 'ให้ผู้รับการตรวจเป่าที่เซนเซอร์ ค่าสูงสุดจะถูกจำไว้',
              trailing: TextButton.icon(
                onPressed: hasPeak ? appState.resetPeak : null,
                icon: const Icon(Icons.restart_alt),
                label: const Text('เริ่มรอบใหม่'),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                latest == null
                    ? '–'
                    : appState.measuredValue.toStringAsFixed(1),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: latest == null ? null : status.color,
                ),
              ),
            ),
            Center(
              child: Text(
                'สเกล 0–100 จากเซนเซอร์ MQ-3',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (latest != null) Center(child: StatusPill(status, large: true)),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                _Fact(
                  label: 'ค่าปัจจุบัน',
                  value: latest == null ? '–' : latest.bac.toStringAsFixed(1),
                ),
                _Fact(
                  label: 'เกณฑ์เฝ้าระวัง',
                  value: appState.threshold1.round().toString(),
                ),
                _Fact(
                  label: 'เกณฑ์เกิน',
                  value: appState.threshold2.round().toString(),
                ),
              ],
            ),
            if (appState.isDemo) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  final device = context.read<DeviceLink>();
                  if (device is SimulatedDeviceLink) {
                    device.triggerBlow();
                  }
                },
                icon: const Icon(Icons.air),
                label: const Text('จำลองการเป่า'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ],
            if (link != LinkState.online) ...[
              const SizedBox(height: 16),
              _LinkWarning(link: link, lastUpdate: appState.lastUpdate),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkWarning extends StatelessWidget {
  const _LinkWarning({required this.link, required this.lastUpdate});

  final LinkState link;
  final DateTime? lastUpdate;

  @override
  Widget build(BuildContext context) {
    final color = linkColor(link);
    final message = switch (link) {
      LinkState.stale =>
        'อุปกรณ์ไม่ได้ส่งข้อมูลใหม่ (ล่าสุด ${timeAgo(lastUpdate)}) ค่าที่เห็นอาจไม่ใช่ค่าปัจจุบัน',
      LinkState.offline =>
        'ยังไม่ได้เชื่อมต่อ NETPIE ตรวจอินเทอร์เน็ตหรือค่าคอนฟิกในแท็บอุปกรณ์',
      _ => 'กำลังรอข้อมูลจากอุปกรณ์…',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
