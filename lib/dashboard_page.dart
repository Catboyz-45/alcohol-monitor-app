import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'device_reading.dart';
import 'measurement_summary.dart';
import 'theme.dart';
import 'widgets/common.dart';

// หน้าหลัก: สถานะเครื่องวัด ปุ่มเริ่มตรวจ สรุปวันนี้ และรายการล่าสุด
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.onStartMeasurement,
    required this.onOpenHistory,
    required this.onOpenDevice,
  });

  final VoidCallback onStartMeasurement;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenDevice;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final auth = context.watch<AuthService>();
    final c = context.colors;
    final now = appState.now();
    final today =
        appState.records
            .where((r) => DateRange.today.contains(r.timestamp, now))
            .toList();
    final summary = MeasurementSummary.of(today);
    final recent = appState.records.take(3).toList();

    return PageBody(
      children: [
        PageHeader(
          'ด่านตรวจวันนี้',
          overline: formatThaiLongDate(now),
          trailing: _AccountAvatar(auth: auth, onTap: onOpenDevice),
        ),
        if (appState.isDemo) ...[
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: DemoChip()),
        ],
        const SizedBox(height: 16),
        _DeviceStatusCard(appState: appState, onTap: onOpenDevice),
        const SizedBox(height: 16),
        _StartCard(onTap: onStartMeasurement),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatTile(label: 'ตรวจแล้ว', value: '${summary.total}'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'เกินเกณฑ์',
                value: '${summary.count(AlertStatus.danger)}',
                status:
                    summary.count(AlertStatus.danger) > 0
                        ? AlertStatus.danger
                        : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  appState.hasCloud
                      ? StatTile(
                        label: 'รอซิงก์',
                        value: '${appState.pendingSyncCount}',
                        status:
                            appState.pendingSyncCount > 0
                                ? AlertStatus.warning
                                : null,
                      )
                      : StatTile(
                        label: 'ค่าเฉลี่ย',
                        value: summary.average?.toStringAsFixed(1) ?? '-',
                      ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'ตรวจล่าสุด',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
            ),
            if (recent.isNotEmpty)
              TextButton(
                onPressed: onOpenHistory,
                child: const Text('ดูทั้งหมด'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (recent.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 40, color: c.muted),
                const SizedBox(height: 8),
                Text(
                  'ยังไม่มีผลตรวจ',
                  style: TextStyle(fontWeight: FontWeight.w600, color: c.ink),
                ),
                Text(
                  'กด "เริ่มตรวจผู้ขับขี่" เพื่อตรวจคนแรก',
                  style: TextStyle(color: c.muted),
                ),
              ],
            ),
          )
        else
          GroupedList(
            children: [
              for (final r in recent)
                RecordRow(
                  record: r,
                  subtitle:
                      '${r.licensePlate} · '
                      '${isSameDay(r.timestamp, now) ? formatTime(r.timestamp) : formatThaiDateTime(r.timestamp)}',
                  onTap: onOpenHistory,
                ),
            ],
          ),
      ],
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.auth, required this.onTap});

  final AuthService auth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final email = auth.email;
    final initial =
        auth.mode == AuthMode.signedIn && email != null && email.isNotEmpty
            ? email[0].toUpperCase()
            : null;
    return Semantics(
      button: true,
      label: 'บัญชีและเครื่องวัด',
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primarySoft,
            shape: BoxShape.circle,
          ),
          child:
              initial == null
                  ? Icon(Icons.person_outline, color: c.primary)
                  : Text(
                    initial,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: c.primary,
                    ),
                  ),
        ),
      ),
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard({required this.appState, required this.onTap});

  final AppState appState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final link = appState.link;
    final detail = switch (link) {
      LinkState.online =>
        '${appState.isDemo ? 'เครื่องจำลอง' : 'ESP32'} · ส่งข้อมูลล่าสุด '
            '${timeAgo(appState.lastUpdate, now: appState.now())}',
      LinkState.stale =>
        'เงียบไปตั้งแต่ ${timeAgo(appState.lastUpdate, now: appState.now())} ตรวจว่าบอร์ดเปิดอยู่',
      LinkState.offline => 'ต่อ NETPIE ไม่ได้ ตรวจอินเทอร์เน็ต',
      LinkState.connecting => 'รอข้อมูลแรกจากบอร์ด',
    };
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          StatusDot(
            color: linkColor(context, link),
            halo: linkSoft(context, link),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  linkLabel(link),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                Text(detail, style: TextStyle(fontSize: 13, color: c.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.muted),
        ],
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      child: Material(
        color: c.primary,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.onPrimary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.air_rounded, color: c.onPrimary),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, color: c.onPrimary),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'เริ่มตรวจผู้ขับขี่',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.onPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'กรอกข้อมูล → ให้เป่า → บันทึกผล',
                  style: TextStyle(
                    fontSize: 14,
                    color: c.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
