import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'config.dart';
import 'device_link.dart';
import 'device_reading.dart';
import 'theme.dart';
import 'widgets/alcohol_gauge.dart';
import 'widgets/common.dart';

// หน้าอุปกรณ์: สถานะการเชื่อมต่อ, ตั้งค่า threshold, เกจค่าสด และบัญชีผู้ใช้
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageBody(
      children: [
        _ConnectionCard(),
        SizedBox(height: 16),
        _ThresholdCard(),
        SizedBox(height: 16),
        _GaugeCard(),
        SizedBox(height: 16),
        _AccountCard(),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final link = appState.link;

    final outline = Theme.of(context).colorScheme.outline;
    final mqtt =
        appState.isDemo
            ? ('จำลอง', AlertStatus.safe.color)
            : !AppConfig.hasMqtt
            ? ('ไม่ได้ตั้งค่า', outline)
            : switch (appState.mqttConnected) {
              true => ('เชื่อมต่อแล้ว', AlertStatus.safe.color),
              false => ('ไม่ได้เชื่อมต่อ', AlertStatus.danger.color),
              null => ('กำลังเชื่อมต่อ', outline),
            };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              'การเชื่อมต่อ',
              subtitle:
                  'ข้อมูลล่าสุด ${timeAgo(appState.lastUpdate, now: appState.now())}',
              trailing: IconButton(
                tooltip: 'ขอสถานะล่าสุดจากบอร์ด',
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<DeviceLink>().refresh(),
              ),
            ),
            const SizedBox(height: 12),
            _StatusRow(
              icon: Icons.memory,
              label: 'บอร์ด ESP32',
              value: linkLabel(link),
              color: linkColor(link),
            ),
            _StatusRow(
              icon: Icons.bolt_outlined,
              label: 'NETPIE MQTT',
              value: mqtt.$1,
              color: mqtt.$2,
            ),
            if (link == LinkState.stale)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'แอปต่อ NETPIE ได้ แต่บอร์ดไม่ได้ส่งข้อมูลเกิน '
                  '${AppState.staleAfter.inSeconds} วินาที ตรวจว่าบอร์ดเปิดอยู่และต่อ Wi-Fi ได้',
                  style: TextStyle(color: linkColor(link)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
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
  double? _t1;
  double? _t2;
  bool _sending = false;

  Future<void> _send(AppState appState) async {
    final t1 = _t1 ?? appState.threshold1;
    final t2 = _t2 ?? appState.threshold2;
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
          ..showSnackBar(
            SnackBar(
              content: Text('ส่งค่าไม่สำเร็จ: $e'),
              backgroundColor: AlertStatus.danger.color,
            ),
          );
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
    final theme = Theme.of(context);
    // ใช้ค่าที่อุปกรณ์รายงาน จนกว่าผู้ใช้จะเริ่มลาก slider
    final t1 = _t1 ?? appState.threshold1;
    final t2 = _t2 ?? appState.threshold2;
    final edited = _t1 != null || _t2 != null;
    final canSend =
        appState.isDemo ||
        (AppConfig.hasMqtt && appState.mqttConnected == true);

    Widget ackStatus() {
      if (!canSend) {
        return Text(
          AppConfig.hasMqtt
              ? 'ต้องเชื่อมต่อ MQTT ก่อนจึงจะส่งค่าไปที่บอร์ดได้'
              : 'ยังไม่ได้ตั้งค่า APP_MQTT_* จึงส่งค่าไปที่บอร์ดไม่ได้',
          style: TextStyle(color: theme.colorScheme.outline),
        );
      }
      if (appState.pendingThresholds != null) {
        final overdue = appState.thresholdsAckOverdue;
        return Row(
          children: [
            if (!overdue)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.schedule, size: 16, color: AlertStatus.warning.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                overdue
                    ? 'อุปกรณ์ยังไม่ยืนยันค่าใหม่ ตรวจว่าบอร์ดออนไลน์อยู่'
                    : 'ส่งแล้ว รออุปกรณ์ยืนยัน…',
                style: TextStyle(
                  color: overdue ? AlertStatus.warning.color : null,
                ),
              ),
            ),
          ],
        );
      }
      if (appState.thresholdsConfirmedAt != null) {
        return Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: AlertStatus.safe.color),
            const SizedBox(width: 8),
            Text(
              'อุปกรณ์รับค่าแล้ว ${timeAgo(appState.thresholdsConfirmedAt, now: appState.now())}',
              style: TextStyle(color: AlertStatus.safe.color),
            ),
          ],
        );
      }
      return Text(
        'ค่าที่แสดงคือค่าที่บอร์ดใช้อยู่ตอนนี้',
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(
              'เกณฑ์แจ้งเตือน',
              subtitle: 'บอร์ดเปิดไฟเตือนเมื่อค่าถึงเกณฑ์ (สเกล 0–100)',
            ),
            const SizedBox(height: 12),
            _ThresholdSlider(
              label: 'เกณฑ์เฝ้าระวัง',
              color: AlertStatus.warning.color,
              value: t1,
              onChanged:
                  (value) => setState(() {
                    _t1 = value;
                    if (value > t2) {
                      _t2 = value;
                    }
                  }),
            ),
            _ThresholdSlider(
              label: 'เกณฑ์เกิน',
              color: AlertStatus.danger.color,
              value: t2,
              onChanged:
                  (value) => setState(() {
                    _t2 = value;
                    if (value < t1) {
                      _t1 = value;
                    }
                  }),
            ),
            const SizedBox(height: 8),
            ackStatus(),
            const SizedBox(height: 16),
            Row(
              children: [
                if (edited)
                  TextButton(
                    onPressed:
                        () => setState(() {
                          _t1 = null;
                          _t2 = null;
                        }),
                    child: const Text('ยกเลิก'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed:
                      !canSend || _sending || !edited
                          ? null
                          : () => _send(appState),
                  icon:
                      _sending
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send),
                  label: const Text('ส่งไปที่บอร์ด'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value.round().toString(),
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          min: 1,
          max: kScaleMax,
          divisions: 99,
          activeColor: color,
          value: value.clamp(1, kScaleMax),
          label: value.round().toString(),
          semanticFormatterCallback: (v) => '$label ${v.round()}',
          onChanged: (v) => onChanged(v.roundToDouble()),
        ),
      ],
    );
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final latest = appState.latest;

    Widget legend(AlertStatus status) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: status.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(status.label),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              'ค่าสดจากเซนเซอร์',
              trailing: latest == null ? null : StatusPill(latest.status),
            ),
            const SizedBox(height: 16),
            AlcoholGauge(
              value: latest?.bac ?? 0,
              threshold1: appState.threshold1,
              threshold2: appState.threshold2,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                latest == null ? '–' : latest.bac.toStringAsFixed(1),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Center(
              child: Text(
                latest?.raw == null
                    ? 'สเกล 0–100'
                    : 'ค่า ADC ดิบ ${latest!.raw}',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [for (final s in AlertStatus.values) legend(s)],
            ),
            const SizedBox(height: 12),
            Text(
              'ค่าในแอปเป็นสเกลเชิงเส้นจาก ADC ของ MQ-3 ยังไม่ได้สอบเทียบเป็นค่า BAC '
              'จึงไม่ควรใช้ตัดสินทางกฎหมาย',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
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
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('ออก'),
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
    final (String title, String subtitle) = switch (auth.mode) {
      AuthMode.signedIn => (
        auth.email ?? 'เจ้าหน้าที่',
        'ข้อมูลซิงก์กับ Cloud Firestore',
      ),
      AuthMode.demo => ('โหมดสาธิต', 'อุปกรณ์จำลอง · ข้อมูลอยู่ในเครื่องนี้'),
      _ => ('ไม่ได้ตั้งค่า Firebase', 'ประวัติเก็บในเครื่องนี้เท่านั้น'),
    };
    final canLeave =
        auth.mode == AuthMode.signedIn || auth.mode == AuthMode.demo;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing:
            canLeave
                ? TextButton(
                  onPressed: () => _signOut(context),
                  child: Text(
                    auth.mode == AuthMode.demo ? 'ออกจากโหมด' : 'ออกจากระบบ',
                  ),
                )
                : null,
      ),
    );
  }
}
