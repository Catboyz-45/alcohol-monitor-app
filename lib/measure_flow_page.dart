import 'dart:math' as math;

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

// ผลที่ส่งกลับไปหน้าหลักเมื่อบันทึกสำเร็จ
class MeasureFlowResult {
  const MeasureFlowResult({required this.synced});

  final bool synced;
}

// ค่าที่ล็อกไว้ตอนกด "ใช้ค่านี้" (บอร์ดยังส่งค่ามาเรื่อย ๆ แต่ผลตรวจต้องไม่เปลี่ยนตาม)
class _Measurement {
  const _Measurement({
    required this.value,
    required this.status,
    required this.threshold1,
    required this.threshold2,
    required this.at,
  });

  final double value;
  final AlertStatus status;
  final double threshold1;
  final double threshold2;
  final DateTime at;
}

// การตรวจหนึ่งครั้ง 3 ขั้น: ข้อมูลผู้ถูกตรวจ → เป่า → ผลตรวจ/บันทึก
// เป่าก่อนแล้วค่อยกรอกข้อมูลก็ได้ (ด่านที่รถติด)
class MeasureFlowPage extends StatefulWidget {
  const MeasureFlowPage({super.key});

  @override
  State<MeasureFlowPage> createState() => _MeasureFlowPageState();
}

class _MeasureFlowPageState extends State<MeasureFlowPage> {
  static const _info = 0;
  static const _blow = 1;
  static const _result = 2;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _idCard = TextEditingController();
  final _age = TextEditingController();
  final _plate = TextEditingController();
  String? _province;

  int _step = _info;
  _Measurement? _measurement;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // ค่าสูงสุดต้องเป็นของผู้ถูกตรวจคนนี้เท่านั้น
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().resetPeak();
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _idCard.dispose();
    _age.dispose();
    _plate.dispose();
    super.dispose();
  }

  bool get _hasAnyInput =>
      _name.text.isNotEmpty ||
      _idCard.text.isNotEmpty ||
      _age.text.isNotEmpty ||
      _plate.text.isNotEmpty ||
      _province != null ||
      _measurement != null;

  bool get _infoComplete {
    final age = int.tryParse(_age.text.trim());
    return _name.text.trim().isNotEmpty &&
        isValidThaiId(_idCard.text.trim()) &&
        age != null &&
        age >= 1 &&
        age <= 120 &&
        _plate.text.trim().isNotEmpty &&
        (_province ?? '').isNotEmpty;
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _nextFromInfo() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _goTo(_measurement == null ? _blow : _result);
  }

  void _useCurrentValue() {
    final appState = context.read<AppState>();
    if (appState.latest == null) {
      _showSnack('ยังไม่มีค่าจากเครื่องวัด ตรวจการเชื่อมต่อก่อน');
      return;
    }
    final value = double.parse(appState.measuredValue.toStringAsFixed(1));
    final t1 = appState.threshold1;
    final t2 = appState.threshold2;
    setState(() {
      _measurement = _Measurement(
        value: value,
        status: AlertStatusCode.fromLevel(alertLevelFor(value, t1, t2)),
        threshold1: t1,
        threshold2: t2,
        at: appState.now(),
      );
    });
    _goTo(_result);
  }

  void _blowAgain() {
    context.read<AppState>().resetPeak();
    setState(() => _measurement = null);
    _goTo(_blow);
  }

  Future<void> _save() async {
    final m = _measurement;
    if (m == null) {
      _goTo(_blow);
      return;
    }
    if (!_infoComplete) {
      _goTo(_info);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _formKey.currentState?.validate(),
      );
      _showSnack('กรอกข้อมูลผู้ถูกตรวจให้ครบก่อนบันทึก');
      return;
    }
    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    final now = appState.now();
    final record = MeasurementRecord(
      // ใช้เวลาระดับไมโครวินาทีเป็น id เพื่อลดโอกาสชนกันเมื่อหลายเครื่องบันทึกพร้อมกัน
      id: '${now.millisecondsSinceEpoch}-${now.microsecond}',
      name: _name.text.trim(),
      idCard: _idCard.text.trim(),
      age: int.parse(_age.text.trim()),
      licensePlate: _plate.text.trim(),
      province: _province ?? '',
      alcoholValue: m.value,
      status: m.status.code,
      timestamp: m.at,
    );
    setState(() => _saving = true);
    await appState.addRecord(record);
    appState.resetPeak();
    final synced =
        !appState.hasCloud ||
        appState.records.any((r) => r.id == record.id && r.synced);
    navigator.pop(MeasureFlowResult(synced: synced));
  }

  Future<void> _handleBack() async {
    if (_step == _result) {
      _goTo(_blow);
      return;
    }
    if (_step == _blow) {
      _goTo(_info);
      return;
    }
    if (!_hasAnyInput) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('ยกเลิกการตรวจนี้?'),
            content: const Text('ข้อมูลที่กรอกและค่าที่วัดได้จะไม่ถูกบันทึก'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('ตรวจต่อ'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  'ยกเลิกการตรวจ',
                  style: TextStyle(color: context.colors.dangerInk),
                ),
              ),
            ],
          ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = _measurement;
    final body = switch (_step) {
      _info => _InfoStep(
        formKey: _formKey,
        name: _name,
        idCard: _idCard,
        age: _age,
        plate: _plate,
        province: _province,
        onProvince: (value) => setState(() => _province = value),
        onChanged: () => setState(() {}),
        onBlowFirst: m == null ? () => _goTo(_blow) : null,
      ),
      _blow => _BlowStep(subjectName: _name.text.trim()),
      _ => _ResultStep(
        measurement: m!,
        name: _name.text.trim(),
        idCard: _idCard.text.trim(),
        age: _age.text.trim(),
        plate: _plate.text.trim(),
        province: _province,
        infoComplete: _infoComplete,
        onBack: _handleBack,
        onEditInfo: () => _goTo(_info),
      ),
    };

    final bottom = switch (_step) {
      _info => FilledButton.icon(
        onPressed: _nextFromInfo,
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(m == null ? 'ถัดไป: ให้เป่า' : 'ถัดไป: ดูผลตรวจ'),
      ),
      _blow => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.read<AppState>().resetPeak(),
              child: const Text('เป่าใหม่'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _useCurrentValue,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('ใช้ค่านี้ ดูผล'),
            ),
          ),
        ],
      ),
      _ => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _blowAgain,
              child: const Text('เป่าซ้ำ'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon:
                  _saving
                      ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.onPrimary,
                        ),
                      )
                      : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'กำลังบันทึก…' : 'บันทึกผลตรวจ'),
            ),
          ),
        ],
      ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          children: [
            if (_step != _result) _StepHeader(step: _step, onBack: _handleBack),
            Expanded(child: body),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: SizedBox(width: double.infinity, child: bottom),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// หัวหน้าขั้นตอน + แถบความคืบหน้า 3 ขั้น
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.onBack});

  final int step;
  final VoidCallback onBack;

  static const _labels = ['ข้อมูล', 'เป่า', 'ผลตรวจ'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 20, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip:
                            step == 0 ? 'ยกเลิกการตรวจ' : 'กลับไปขั้นก่อนหน้า',
                        onPressed: onBack,
                        icon: Icon(
                          step == 0
                              ? Icons.close_rounded
                              : Icons.arrow_back_rounded,
                          color: c.ink,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'ตรวจใหม่',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                      ),
                      Text(
                        'ขั้นที่ ${step + 1} จาก 3',
                        style: TextStyle(fontSize: 14, color: c.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: i <= step ? c.primary : c.border,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  i < step ? '${_labels[i]} ✓' : _labels[i],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        i == step
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                    color: i <= step ? c.primary : c.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ขั้นที่ 1: ข้อมูลผู้ถูกตรวจ
// ---------------------------------------------------------------------------

class _InfoStep extends StatelessWidget {
  const _InfoStep({
    required this.formKey,
    required this.name,
    required this.idCard,
    required this.age,
    required this.plate,
    required this.province,
    required this.onProvince,
    required this.onChanged,
    required this.onBlowFirst,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController idCard;
  final TextEditingController age;
  final TextEditingController plate;
  final String? province;
  final ValueChanged<String> onProvince;
  final VoidCallback onChanged;
  final VoidCallback? onBlowFirst;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final id = idCard.text.trim();
    final idValid = id.length == 13 && isValidThaiId(id);

    return Form(
      key: formKey,
      child: PageBody(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(
            'ผู้ถูกตรวจเป็นใคร',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 18),
          LabeledField(
            label: 'ชื่อ-นามสกุล',
            child: TextFormField(
              controller: name,
              textInputAction: TextInputAction.next,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(hintText: 'เช่น สมชาย ใจดี'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'กรุณากรอกชื่อ-นามสกุล'
                          : null,
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'เลขบัตรประชาชน',
            helper: idValid ? 'เลขถูกต้อง (ตรวจหลักสุดท้ายแล้ว)' : null,
            helperColor: c.safeInk,
            child: TextFormField(
              controller: idCard,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onChanged: (_) => onChanged(),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              style: const TextStyle(letterSpacing: 0.5),
              decoration: InputDecoration(
                hintText: '13 หลัก',
                suffixIcon:
                    idValid
                        ? Icon(Icons.check_rounded, color: c.safeInk)
                        : null,
                enabledBorder:
                    idValid
                        ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: c.safeInk, width: 2),
                        )
                        : null,
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
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabeledField(
                  label: 'อายุ',
                  child: TextFormField(
                    controller: age,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => onChanged(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(suffixText: 'ปี'),
                    validator: (value) {
                      final n = int.tryParse(value?.trim() ?? '');
                      return n == null || n < 1 || n > 120
                          ? 'อายุ 1–120'
                          : null;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: LabeledField(
                  label: 'ทะเบียนรถ',
                  child: TextFormField(
                    controller: plate,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      hintText: 'เช่น 1กก 1234',
                    ),
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'กรุณากรอกทะเบียนรถ'
                                : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'จังหวัดของทะเบียน',
            child: _ProvinceField(value: province, onChanged: onProvince),
          ),
          if (onBlowFirst != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'รีบอยู่?',
                      style: TextStyle(color: c.onPrimarySoft, fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: onBlowFirst,
                    child: const Text('ให้เป่าก่อน แล้วค่อยกรอก'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ช่องเลือกจังหวัด: กดแล้วเปิดรายการที่พิมพ์ค้นหาได้
class _ProvinceField extends StatelessWidget {
  const _ProvinceField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  Future<void> _pick(BuildContext context, FormFieldState<String> field) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProvincePicker(selected: value),
    );
    if (picked != null) {
      onChanged(picked);
      field.didChange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FormField<String>(
      initialValue: value,
      validator: (_) => (value ?? '').isEmpty ? 'กรุณาเลือกจังหวัด' : null,
      builder:
          (field) => InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pick(context, field),
            child: InputDecorator(
              isEmpty: value == null,
              decoration: InputDecoration(
                hintText: 'เลือกจังหวัด',
                errorText: field.errorText,
                suffixIcon: Icon(Icons.search_rounded, color: c.muted),
              ),
              child: value == null ? null : Text(value!),
            ),
          ),
    );
  }
}

class _ProvincePicker extends StatefulWidget {
  const _ProvincePicker({required this.selected});

  final String? selected;

  @override
  State<_ProvincePicker> createState() => _ProvincePickerState();
}

class _ProvincePickerState extends State<_ProvincePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _query.trim();
    final items =
        q.isEmpty
            ? thaiProvinces
            : thaiProvinces.where((p) => p.contains(q)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'พิมพ์ค้นหา เช่น เชียง',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child:
                  items.isEmpty
                      ? Center(
                        child: Text(
                          'ไม่พบจังหวัดนี้',
                          style: TextStyle(color: c.muted),
                        ),
                      )
                      : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final p = items[i];
                          final selected = p == widget.selected;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            title: Text(
                              p,
                              style: TextStyle(
                                fontWeight:
                                    selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                              ),
                            ),
                            trailing:
                                selected
                                    ? Icon(
                                      Icons.check_rounded,
                                      color: c.primary,
                                    )
                                    : null,
                            onTap: () => Navigator.of(context).pop(p),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ขั้นที่ 2: เป่า
// ---------------------------------------------------------------------------

class _BlowStep extends StatelessWidget {
  const _BlowStep({required this.subjectName});

  final String subjectName;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final c = context.colors;
    final link = appState.link;
    final latest = appState.latest;
    final hasPeak = appState.peakBac != null;
    final value = appState.measuredValue;
    final status = appState.measuredStatus;
    final t1 = appState.threshold1;
    final t2 = appState.threshold2;

    return PageBody(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              StatusDot(
                color: linkColor(context, link),
                halo: linkSoft(context, link),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  link == LinkState.online
                      ? 'เครื่องวัดออนไลน์'
                      : linkLabel(link),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                  ),
                ),
              ),
              if (subjectName.isNotEmpty)
                Flexible(
                  child: Text(
                    subjectName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                ),
            ],
          ),
        ),
        if (link != LinkState.online) ...[
          const SizedBox(height: 10),
          _Notice(
            color: linkColor(context, link),
            background: linkSoft(context, link),
            text: switch (link) {
              LinkState.stale =>
                'เครื่องวัดไม่ได้ส่งข้อมูลใหม่ (ล่าสุด ${timeAgo(appState.lastUpdate, now: appState.now())}) ค่าที่เห็นอาจไม่ใช่ค่าปัจจุบัน',
              LinkState.offline =>
                'ยังไม่ได้เชื่อมต่อ NETPIE ตรวจอินเทอร์เน็ตหรือดูที่แท็บเครื่องวัด',
              _ => 'กำลังรอข้อมูลจากเครื่องวัด…',
            },
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: BreathGauge(
            value: latest == null ? null : value,
            current: latest?.bac,
            status: status,
            threshold1: t1,
            threshold2: t2,
            caption:
                hasPeak
                    ? 'ค่าสูงสุดของการเป่านี้'
                    : 'ค่าตอนนี้ (ยังไม่พบการเป่า)',
          ),
        ),
        if (appState.isDemo) ...[
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () {
                final device = context.read<DeviceLink>();
                if (device is SimulatedDeviceLink) {
                  device.triggerBlow();
                }
              },
              icon: const Icon(Icons.air_rounded),
              label: const Text('จำลองการเป่า'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.air_rounded, color: c.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ให้เป่ายาวต่อเนื่อง 3–5 วินาที',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      'แอปจำค่าสูงสุดไว้ให้เอง ไม่ต้องรีบจดจากจอบอร์ด',
                      style: TextStyle(fontSize: 14, color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (s, text) in [
              (AlertStatus.safe, 'ปลอดภัย < ${t1.round()}'),
              (
                AlertStatus.warning,
                'เฝ้าระวัง ${t1.round()}–${t2.round() - 1}',
              ),
              (AlertStatus.danger, 'เกินเกณฑ์ ≥ ${t2.round()}'),
            ]) ...[
              if (s != AlertStatus.safe) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.statusSoft(s),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.statusInk(s),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.color,
    required this.background,
    required this.text,
  });

  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// มาตรวัดวง 270° แบ่งโซนตามเกณฑ์ ตัวเลขใหญ่ตรงกลาง
class BreathGauge extends StatelessWidget {
  const BreathGauge({
    super.key,
    required this.value,
    required this.current,
    required this.status,
    required this.threshold1,
    required this.threshold2,
    required this.caption,
  });

  final double? value;
  final double? current;
  final AlertStatus status;
  final double threshold1;
  final double threshold2;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = value;
    return Semantics(
      label:
          v == null
              ? 'ยังไม่มีค่าจากเครื่องวัด'
              : '$caption ${v.toStringAsFixed(1)} จาก 100 ${status.label}',
      child: SizedBox(
        width: 280,
        height: 262,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GaugePainter(
                  value: v ?? 0,
                  threshold1: threshold1,
                  threshold2: threshold2,
                  valueColor: v == null ? c.border : status.fill,
                  zones: [c.safeSoft, c.warningSoft, c.dangerSoft],
                ),
              ),
            ),
            Positioned(
              top: 66,
              left: 0,
              right: 0,
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    Text(
                      caption,
                      style: TextStyle(fontSize: 14, color: c.muted),
                    ),
                    Text(
                      v == null ? '–' : v.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 72,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (v != null) StatusPill(status, large: true),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 0,
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Text('0', style: TextStyle(fontSize: 13, color: c.muted)),
                    Expanded(
                      child: Text(
                        current == null
                            ? ''
                            : 'ค่าตอนนี้ ${current!.toStringAsFixed(1)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: c.muted),
                      ),
                    ),
                    Text('100', style: TextStyle(fontSize: 13, color: c.muted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.threshold1,
    required this.threshold2,
    required this.valueColor,
    required this.zones,
  });

  final double value;
  final double threshold1;
  final double threshold2;
  final Color valueColor;
  final List<Color> zones;

  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;
  static const _stroke = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - _stroke / 2 - 4;
    final center = Offset(size.width / 2, size.width / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    double angleOf(double v) =>
        _start + _sweep * (v.clamp(0, kScaleMax) / kScaleMax);

    final zone =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke;
    final bounds = [0.0, threshold1, threshold2, kScaleMax];
    for (var i = 0; i < 3; i++) {
      final a = angleOf(bounds[i]);
      final b = angleOf(bounds[i + 1]);
      if (b > a) {
        canvas.drawArc(rect, a, b - a, false, zone..color = zones[i]);
      }
    }
    if (value > 0) {
      canvas.drawArc(
        rect,
        _start,
        angleOf(value) - _start,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..color = valueColor,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value ||
      old.threshold1 != threshold1 ||
      old.threshold2 != threshold2 ||
      old.valueColor != valueColor ||
      old.zones != zones;
}

// ---------------------------------------------------------------------------
// ขั้นที่ 3: ผลตรวจ
// ---------------------------------------------------------------------------

class _ResultStep extends StatelessWidget {
  const _ResultStep({
    required this.measurement,
    required this.name,
    required this.idCard,
    required this.age,
    required this.plate,
    required this.province,
    required this.infoComplete,
    required this.onBack,
    required this.onEditInfo,
  });

  final _Measurement measurement;
  final String name;
  final String idCard;
  final String age;
  final String plate;
  final String? province;
  final bool infoComplete;
  final VoidCallback onBack;
  final VoidCallback onEditInfo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = measurement;
    final s = m.status;
    final fg = s.onFill;
    final caption = switch (s) {
      AlertStatus.danger =>
        'ถึงเกณฑ์เกิน (${m.threshold2.round()}) · ดำเนินการตามขั้นตอน',
      AlertStatus.warning =>
        'อยู่ระหว่างเกณฑ์เฝ้าระวัง (${m.threshold1.round()}) กับเกณฑ์เกิน (${m.threshold2.round()})',
      AlertStatus.safe => 'ต่ำกว่าเกณฑ์เฝ้าระวัง (${m.threshold1.round()})',
    };

    Widget row(String label, String value, {bool last = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(fontSize: 14, color: c.muted)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: s.fill,
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 20, 28),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'กลับไปหน้าเป่า',
                            onPressed: onBack,
                            icon: Icon(Icons.arrow_back_rounded, color: fg),
                          ),
                          Expanded(
                            child: Text(
                              'ผลตรวจ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: fg,
                              ),
                            ),
                          ),
                          Text(
                            'ขั้นที่ 3 จาก 3',
                            style: TextStyle(
                              fontSize: 14,
                              color: fg.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        label:
                            'ผลตรวจ ${s.label} ค่า ${m.value.toStringAsFixed(1)}',
                        child: ExcludeSemantics(
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: fg.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(s.icon, color: fg, size: 36),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                s.label,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: fg,
                                ),
                              ),
                              Text(
                                m.value.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 96,
                                  height: 1.05,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -2,
                                  color: fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          caption,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: fg.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!infoComplete) ...[
                    _Notice(
                      color: c.warningInk,
                      background: c.warningSoft,
                      text:
                          'ยังไม่ได้กรอกข้อมูลผู้ถูกตรวจครบ กรอกให้ครบก่อนบันทึก',
                    ),
                    const SizedBox(height: 12),
                  ],
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        row(
                          'ผู้ถูกตรวจ',
                          name.isEmpty
                              ? '-'
                              : age.isEmpty
                              ? name
                              : '$name · $age ปี',
                        ),
                        row(
                          'เลขบัตร',
                          idCard.isEmpty ? '-' : maskThaiId(idCard),
                        ),
                        row(
                          'ทะเบียน',
                          plate.isEmpty
                              ? '-'
                              : '$plate ${province ?? ''}'.trim(),
                        ),
                        row('เวลา', formatThaiDateTime(m.at), last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onEditInfo,
                      child: Text(
                        infoComplete
                            ? 'แก้ไขข้อมูลผู้ถูกตรวจ'
                            : 'กรอกข้อมูลผู้ถูกตรวจ',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ค่าเป็นสเกล 0–100 จากเซนเซอร์ MQ-3 ยังไม่ได้สอบเทียบเป็นค่า BAC '
                    'ตามกฎหมาย ใช้ประกอบการคัดกรองเท่านั้น',
                    style: TextStyle(fontSize: 13, height: 1.5, color: c.muted),
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
