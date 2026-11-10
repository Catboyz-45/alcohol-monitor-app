import 'package:flutter/material.dart';

import '../app_state.dart';
import '../device_reading.dart';
import '../theme.dart';

// ป้ายสถานะผลตรวจ (ปลอดภัย / เฝ้าระวัง / เกินเกณฑ์)
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.large = false});

  final AlertStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = c.statusInk(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 10,
        vertical: large ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: c.statusSoft(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: large ? 18 : 15, color: ink),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.w600,
              fontSize: large ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

String linkLabel(LinkState link) => switch (link) {
  LinkState.online => 'เครื่องวัดพร้อมใช้งาน',
  LinkState.stale => 'เครื่องวัดไม่ส่งข้อมูล',
  LinkState.offline => 'ยังไม่ได้เชื่อมต่อ',
  LinkState.connecting => 'กำลังเชื่อมต่อ…',
};

// ป้ายสั้นสำหรับที่แคบ (บรรทัดสถานะในการ์ด)
String linkShortLabel(LinkState link) => switch (link) {
  LinkState.online => 'ออนไลน์',
  LinkState.stale => 'ไม่ส่งข้อมูล',
  LinkState.offline => 'ไม่ได้เชื่อมต่อ',
  LinkState.connecting => 'กำลังเชื่อมต่อ',
};

Color linkColor(BuildContext context, LinkState link) {
  final c = context.colors;
  return switch (link) {
    LinkState.online => c.safeInk,
    LinkState.stale => c.warningInk,
    LinkState.offline => c.dangerInk,
    LinkState.connecting => c.muted,
  };
}

Color linkSoft(BuildContext context, LinkState link) {
  final c = context.colors;
  return switch (link) {
    LinkState.online => c.safeSoft,
    LinkState.stale => c.warningSoft,
    LinkState.offline => c.dangerSoft,
    LinkState.connecting => c.surfaceMuted,
  };
}

// จุดสถานะมีวงแสงรอบ ๆ
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, required this.halo});

  final Color color;
  final Color halo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: halo, shape: BoxShape.circle),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

// การ์ดพื้นขาวขอบบาง ใช้แทน Card เมื่ออยากคุม padding เอง
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(16);
    return Material(
      color: color ?? c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: color == null ? BorderSide(color: c.border) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// หัวของแต่ละการ์ด
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.subtitle});

  final String text;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: TextStyle(fontSize: 13, color: c.muted)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// หัวหน้าจอแบบตัวใหญ่ (แทน AppBar)
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.overline, this.trailing});

  final String title;
  final String? overline;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null)
                Text(overline!, style: TextStyle(fontSize: 14, color: c.muted)),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ป้าย "โหมดสาธิต" เล็ก ๆ บนหัวหน้าจอ (แทนแถบเต็มความกว้าง)
class DemoChip extends StatelessWidget {
  const DemoChip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: 'ค่าจากเครื่องวัดจำลอง ไม่ใช่ผลตรวจจริง',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.warningSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined, size: 15, color: c.warningInk),
            const SizedBox(width: 4),
            Text(
              'โหมดสาธิต',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.warningInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ป้ายชื่อเหนือช่องกรอก (อ่านง่ายกว่า label ที่ลอยอยู่ในช่อง)
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.helper,
    this.helperColor,
  });

  final String label;
  final Widget child;
  final String? helper;
  final Color? helperColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(
            helper!,
            style: TextStyle(fontSize: 13, color: helperColor ?? c.muted),
          ),
        ],
      ],
    );
  }
}

// ตัวเลขสรุปหนึ่งช่อง
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.status,
    this.detail,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? detail;

  // มีค่า = ใช้สีของสถานะนั้นเป็นพื้นและตัวเลข
  final AlertStatus? status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = status;
    final ink = s == null ? c.ink : c.statusInk(s);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            color: s == null ? c.muted : ink,
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            text: value,
            children: [
              if (detail != null)
                TextSpan(
                  text: ' $detail',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          style: TextStyle(
            fontSize: compact ? 22 : 26,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ],
    );
    if (compact) {
      return content;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s == null ? c.surface : c.statusSoft(s),
        borderRadius: BorderRadius.circular(14),
        border: s == null ? Border.all(color: c.border) : null,
      ),
      child: content,
    );
  }
}

// แถวรายการผลตรวจ: ค่าในกล่องสี + ชื่อ + ทะเบียน/เวลา + สถานะ
class RecordRow extends StatelessWidget {
  const RecordRow({
    super.key,
    required this.record,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final MeasurementRecord record;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = record.alertStatus;
    final ink = c.statusInk(status);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.statusSoft(status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                record.alcoholValue.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(height: 4), trailing!],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// รายการหลายแถวในการ์ดเดียว คั่นด้วยเส้นบาง
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

// แถบสัดส่วนสถานะ (ปลอดภัย / เฝ้าระวัง / เกินเกณฑ์)
class StatusRatioBar extends StatelessWidget {
  const StatusRatioBar({super.key, required this.counts, this.height = 10});

  final Map<AlertStatus, int> counts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final label = [
      for (final s in AlertStatus.values) '${s.label} ${counts[s] ?? 0}',
    ].join(' ');
    return Semantics(
      label: label,
      child: SizedBox(
        height: height,
        child:
            total == 0
                ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                )
                : Row(
                  // ให้แต่ละช่วงสูงเต็มแถบ
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in AlertStatus.values)
                      if ((counts[s] ?? 0) > 0)
                        Expanded(
                          flex: counts[s]!,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 1.5,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: s.fill,
                                borderRadius: BorderRadius.circular(height / 2),
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

// จำกัดความกว้างเนื้อหาให้อ่านง่ายบนจอใหญ่/เว็บ
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 32),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

// "เมื่อ 5 วินาทีที่แล้ว" สำหรับเวลาที่ได้ข้อมูลล่าสุด
String timeAgo(DateTime? time, {DateTime? now}) {
  if (time == null) {
    return 'ยังไม่มีข้อมูล';
  }
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inSeconds < 5) {
    return 'เมื่อสักครู่';
  }
  if (diff.inSeconds < 60) {
    return '${diff.inSeconds} วินาทีที่แล้ว';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} นาทีที่แล้ว';
  }
  return formatThaiDateTime(time);
}

const _thaiMonths = [
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

const _thaiWeekdays = [
  'จันทร์',
  'อังคาร',
  'พุธ',
  'พฤหัสบดี',
  'ศุกร์',
  'เสาร์',
  'อาทิตย์',
];

String _two(int n) => n.toString().padLeft(2, '0');

// เวลา เช่น 14:05
String formatTime(DateTime time) {
  final local = time.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

// วันที่แบบไทย ปี พ.ศ. เช่น 18 ต.ค. 2569 14:05
String formatThaiDateTime(DateTime time) {
  final local = time.toLocal();
  return '${local.day} ${_thaiMonths[local.month - 1]} ${local.year + 543} '
      '${formatTime(local)}';
}

// วันพร้อมชื่อวัน เช่น อังคาร 10 พ.ย. 2569
String formatThaiLongDate(DateTime time) {
  final local = time.toLocal();
  return '${_thaiWeekdays[local.weekday - 1]} ${local.day} '
      '${_thaiMonths[local.month - 1]} ${local.year + 543}';
}

// หัวกลุ่มของรายการตามวัน: วันนี้ / เมื่อวาน / 8 พ.ย. 2569
String formatDayHeading(DateTime time, DateTime now) {
  final local = time.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final short = '${local.day} ${_thaiMonths[local.month - 1]}';
  final diff = today.difference(day).inDays;
  if (diff == 0) {
    return 'วันนี้ · $short';
  }
  if (diff == 1) {
    return 'เมื่อวาน · $short';
  }
  return '$short ${local.year + 543}';
}

bool isSameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}
