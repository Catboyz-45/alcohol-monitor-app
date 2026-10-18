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
    final color = status.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 10,
        vertical: large ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: large ? 20 : 16, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: large ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

String linkLabel(LinkState link) => switch (link) {
  LinkState.online => 'อุปกรณ์ออนไลน์',
  LinkState.stale => 'อุปกรณ์ไม่ส่งข้อมูล',
  LinkState.offline => 'เชื่อมต่อไม่ได้',
  LinkState.connecting => 'กำลังเชื่อมต่อ',
};

Color linkColor(LinkState link) => switch (link) {
  LinkState.online => const Color(0xFF16A34A),
  LinkState.stale => const Color(0xFFD97706),
  LinkState.offline => const Color(0xFFDC2626),
  LinkState.connecting => const Color(0xFF64748B),
};

// ชิปสถานะการเชื่อมต่อบน AppBar
class LinkChip extends StatelessWidget {
  const LinkChip({super.key, required this.link, this.onTap});

  final LinkState link;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = linkColor(link);
    return Semantics(
      button: onTap != null,
      label: 'สถานะ: ${linkLabel(link)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                linkLabel(link),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// หัวข้อของแต่ละการ์ด
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.subtitle});

  final String text;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// จำกัดความกว้างเนื้อหาให้อ่านง่ายบนจอใหญ่/เว็บ
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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

// วันที่แบบไทย ปี พ.ศ. เช่น 18 ต.ค. 2569 14:05
String formatThaiDateTime(DateTime time) {
  final local = time.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_thaiMonths[local.month - 1]} ${local.year + 543} $hh:$mm';
}
