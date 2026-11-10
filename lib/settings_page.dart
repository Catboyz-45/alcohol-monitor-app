import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'config.dart';
import 'device_link.dart';
import 'device_reading.dart';
import 'theme.dart';
import 'widgets/common.dart';

// หน้าเครื่องวัด: สถานะ + ค่าสด, ตั้งเกณฑ์แจ้งเตือน และบัญชีผู้ใช้
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDemo = context.select<AppState, bool>((s) => s.isDemo);
    final c = context.colors;
    return PageBody(
      children: [
        PageHeader(
          'เครื่องวัด',
          trailing: IconButton(
            tooltip: 'ขอสถานะล่าสุดจากบอร์ด',
            icon: Icon(Icons.refresh_rounded, color: c.ink),
            onPressed: () => context.read<DeviceLink>().refresh(),
          ),
        ),
        if (isDemo) ...[
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: DemoChip()),
        ],
        const SizedBox(height: 16),
        const _DeviceCard(),
        const SizedBox(height: 14),
        const _ThresholdCard(),
        const SizedBox(height: 14),
        const _AccountCard(),
        const SizedBox(height: 16),
        Text(
          'ค่าในแอปเป็นสเกลเชิงเส้นจาก ADC ของ MQ-3 ยังไม่ได้สอบเทียบเป็นค่า BAC '
          'จึงไม่ควรใช้ตัดสินทางกฎหมาย',
          style: TextStyle(fontSize: 13, height: 1.5, color: c.muted),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final c = context.colors;
    final link = appState.link;
    final latest = appState.latest;

    final mqtt =
        appState.isDemo
            ? 'จำลอง'
            : !AppConfig.hasMqtt
            ? 'ไม่ได้ตั้งค่า'
            : switch (appState.mqttConnected) {
              true => 'NETPIE · TLS',
              false => 'ต่อ NETPIE ไม่ได้',
              null => 'กำลังเชื่อมต่อ',
            };
    final cloud =
        !appState.hasCloud
            ? 'เก็บในเครื่อง'
            : appState.syncError != null
            ? 'ซิงก์ไม่สำเร็จ'
            : appState.pendingSyncCount > 0
            ? 'รอซิงก์ ${appState.pendingSyncCount}'
            : 'ซิงก์ครบแล้ว';

    Widget tile(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ],
        ),
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.memory_rounded, color: c.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.isDemo ? 'เครื่องวัดจำลอง' : 'ESP32 + MQ-3',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      '● ${linkShortLabel(link)}'
                      '${appState.lastUpdate == null ? '' : ' · ${timeAgo(appState.lastUpdate, now: appState.now())}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: linkColor(context, link),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    latest == null ? '–' : latest.bac.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color:
                          latest == null ? c.muted : c.statusInk(latest.status),
                    ),
                  ),
                  Text(
                    'ค่าตอนนี้',
                    style: TextStyle(fontSize: 12, color: c.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              tile('การเชื่อมต่อ', mqtt),
              const SizedBox(width: 8),
              tile('Cloud', cloud),
            ],
          ),
          if (link == LinkState.stale) ...[
            const SizedBox(height: 10),
            Text(
              'แอปต่อ NETPIE ได้ แต่บอร์ดไม่ได้ส่งข้อมูลเกิน '
              '${AppState.staleAfter.inSeconds} วินาที ตรวจว่าบอร์ดเปิดอยู่และต่อ Wi-Fi ได้',
              style: TextStyle(fontSize: 14, color: c.warningInk),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThresholdCard extends StatefulWidget {
  const _ThresholdCard();

  @override
  State<_ThresholdCard> createState() => _ThresholdCardState();
}

class _ThresholdCardState extends State<_ThresholdCard> {
  final _t1Text = TextEditingController();
  final _t2Text = TextEditingController();
  double? _t1;
  double? _t2;
  bool _sending = false;

  @override
  void dispose() {
    _t1Text.dispose();
    _t2Text.dispose();
    super.dispose();
  }

  bool get _edited => _t1 != null || _t2 != null;

  void _setValues(double t1, double t2, {bool fromText = false}) {
    setState(() {
      _t1 = t1;
      _t2 = t2;
    });
    if (!fromText) {
      _t1Text.text = t1.round().toString();
      _t2Text.text = t2.round().toString();
    }
  }

  void _reset() {
    setState(() {
      _t1 = null;
      _t2 = null;
    });
    final appState = context.read<AppState>();
    _t1Text.text = appState.threshold1.round().toString();
    _t2Text.text = appState.threshold2.round().toString();
  }

  void _onText(AppState appState) {
    final a = double.tryParse(_t1Text.text);
    final b = double.tryParse(_t2Text.text);
    _setValues(
      (a ?? _t1 ?? appState.threshold1).clamp(1, kScaleMax).toDouble(),
      (b ?? _t2 ?? appState.threshold2).clamp(1, kScaleMax).toDouble(),
      fromText: true,
    );
  }

  Future<void> _send(AppState appState) async {
    var t1 = _t1 ?? appState.threshold1;
    var t2 = _t2 ?? appState.threshold2;
    if (t1 > t2) {
      (t1, t2) = (t2, t1);
    }
    setState(() => _sending = true);
    try {
      await context.read<DeviceLink>().sendThresholds(t1, t2);
      if (mounted) {
        setState(() {
          _t1 = null;
          _t2 = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('ส่งค่าไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final c = context.colors;
    // ใช้ค่าที่บอร์ดรายงาน จนกว่าผู้ใช้จะเริ่มปรับ
    final t1 = _t1 ?? appState.threshold1;
    final t2 = _t2 ?? appState.threshold2;
    final lo = t1 <= t2 ? t1 : t2;
    final hi = t1 <= t2 ? t2 : t1;
    final canSend =
        appState.isDemo ||
        (AppConfig.hasMqtt && appState.mqttConnected == true);

    // ช่องตัวเลขแสดงค่าของบอร์ดเมื่อยังไม่ได้แก้ (อัปเดตหลังวาดเสร็จ)
    if (!_edited) {
      final a = appState.threshold1.round().toString();
      final b = appState.threshold2.round().toString();
      if (_t1Text.text != a || _t2Text.text != b) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_edited) {
            _t1Text.text = a;
            _t2Text.text = b;
          }
        });
      }
    }

    Widget status() {
      final (IconData? icon, Color fg, Color bg, String text, bool busy) =
          !canSend
              ? (
                Icons.link_off_rounded,
                c.muted,
                c.surfaceMuted,
                AppConfig.hasMqtt
                    ? 'ต้องเชื่อมต่อ NETPIE ก่อนจึงจะส่งค่าไปที่บอร์ดได้'
                    : 'ยังไม่ได้ตั้งค่า APP_MQTT_* จึงส่งค่าไปที่บอร์ดไม่ได้',
                false,
              )
              : _edited
              ? (
                Icons.edit_outlined,
                c.onPrimarySoft,
                c.primarySoft,
                'ยังไม่ได้ส่ง กด "ส่งไปที่บอร์ด" เพื่อใช้ค่าใหม่',
                false,
              )
              : appState.pendingThresholds != null
              ? appState.thresholdsAckOverdue
                  ? (
                    Icons.schedule_rounded,
                    c.warningInk,
                    c.warningSoft,
                    'บอร์ดยังไม่ยืนยันค่าใหม่ ตรวจว่าบอร์ดออนไลน์อยู่',
                    false,
                  )
                  : (
                    null,
                    c.onPrimarySoft,
                    c.primarySoft,
                    'ส่งแล้ว รอบอร์ดยืนยัน…',
                    true,
                  )
              : (
                Icons.check_rounded,
                c.safeInk,
                c.safeSoft,
                appState.thresholdsConfirmedAt != null
                    ? 'บอร์ดรับค่าแล้ว ${timeAgo(appState.thresholdsConfirmedAt, now: appState.now())}'
                    : 'บอร์ดใช้ค่านี้อยู่',
                false,
              );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (busy)
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget numberField({
      required String label,
      required Color color,
      required TextEditingController controller,
    }) => Expanded(
      child: LabeledField(
        label: label,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          onChanged: (_) => _onText(appState),
        ),
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(
            'เกณฑ์แจ้งเตือน',
            subtitle: 'บอร์ดเปิดไฟเตือนเมื่อค่าถึงเกณฑ์ (สเกล 0–100)',
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10,
              rangeTrackShape: _ZoneTrackShape([
                AlertStatus.safe.fill,
                AlertStatus.warning.fill,
                AlertStatus.danger.fill,
              ]),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 13,
                elevation: 3,
                pressedElevation: 6,
              ),
              thumbColor: Colors.white,
              overlayColor: c.primary.withValues(alpha: 0.12),
              showValueIndicator: ShowValueIndicator.onDrag,
            ),
            child: RangeSlider(
              min: 1,
              max: kScaleMax,
              divisions: 99,
              values: RangeValues(
                lo.clamp(1, kScaleMax).toDouble(),
                hi.clamp(1, kScaleMax).toDouble(),
              ),
              labels: RangeLabels('${lo.round()}', '${hi.round()}'),
              semanticFormatterCallback: (v) => '${v.round()}',
              onChanged:
                  (v) => _setValues(
                    v.start.roundToDouble(),
                    v.end.roundToDouble(),
                  ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              numberField(
                label: 'เฝ้าระวังตั้งแต่',
                color: c.warningInk,
                controller: _t1Text,
              ),
              const SizedBox(width: 10),
              numberField(
                label: 'เกินเกณฑ์ตั้งแต่',
                color: c.dangerInk,
                controller: _t2Text,
              ),
            ],
          ),
          const SizedBox(height: 12),
          status(),
          if (_edited) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _sending ? null : _reset,
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed:
                        !canSend || _sending ? null : () => _send(appState),
                    icon:
                        _sending
                            ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.onPrimary,
                              ),
                            )
                            : const Icon(Icons.send_rounded),
                    label: const Text('ส่งไปที่บอร์ด'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// แถบของ RangeSlider ที่ระบายสีเป็น 3 โซนตามตำแหน่งปุ่มทั้งสอง
class _ZoneTrackShape extends RangeSliderTrackShape
    with BaseRangeSliderTrackShape {
  const _ZoneTrackShape(this.colors);

  final List<Color> colors;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset startThumbCenter,
    required Offset endThumbCenter,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    final paint = Paint();
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
    );
    final a = startThumbCenter.dx;
    final b = endThumbCenter.dx;
    canvas.drawRect(
      Rect.fromLTRB(rect.left, rect.top, a, rect.bottom),
      paint..color = colors[0],
    );
    canvas.drawRect(
      Rect.fromLTRB(a, rect.top, b, rect.bottom),
      paint..color = colors[1],
    );
    canvas.drawRect(
      Rect.fromLTRB(b, rect.top, rect.right, rect.bottom),
      paint..color = colors[2],
    );
    canvas.restore();
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  Future<void> _signOut(BuildContext context) async {
    final appState = context.read<AppState>();
    final auth = context.read<AuthService>();
    final pending = appState.hasCloud ? appState.pendingSyncCount : 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              auth.mode == AuthMode.demo ? 'ออกจากโหมดสาธิต?' : 'ออกจากระบบ?',
            ),
            content: Text(
              pending > 0
                  ? 'ยังมี $pending รายการที่ยังไม่ได้ส่งขึ้น cloud '
                      'ถ้าออกตอนนี้ข้อมูลเหล่านี้จะหายจากเครื่อง'
                  : 'ข้อมูลประวัติที่เก็บในเครื่องนี้จะถูกล้าง',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  'ออก',
                  style: TextStyle(color: dialogContext.colors.dangerInk),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }
    await appState.clearLocalData();
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final c = context.colors;
    final (String title, String subtitle) = switch (auth.mode) {
      AuthMode.signedIn => (
        'เจ้าหน้าที่',
        auth.email ?? 'ข้อมูลซิงก์กับ Cloud Firestore',
      ),
      AuthMode.demo => ('โหมดสาธิต', 'เครื่องจำลอง · ข้อมูลอยู่ในเครื่องนี้'),
      _ => ('ไม่ได้ตั้งค่า Firebase', 'ประวัติเก็บในเครื่องนี้เท่านั้น'),
    };
    final canLeave =
        auth.mode == AuthMode.signedIn || auth.mode == AuthMode.demo;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_outline_rounded, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.muted),
                ),
              ],
            ),
          ),
          if (canLeave)
            TextButton(
              onPressed: () => _signOut(context),
              style: TextButton.styleFrom(foregroundColor: c.dangerInk),
              child: Text(
                auth.mode == AuthMode.demo ? 'ออกจากโหมด' : 'ออกจากระบบ',
              ),
            ),
        ],
      ),
    );
  }
}
