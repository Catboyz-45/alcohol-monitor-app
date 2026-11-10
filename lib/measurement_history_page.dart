import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'csv_export.dart';
import 'device_reading.dart';
import 'measurement_summary.dart';
import 'thai_id.dart';
import 'theme.dart';
import 'widgets/common.dart';

// ประวัติการตรวจ: เลือกช่วงเวลา สรุปผล ค้นหา/กรอง และส่งออก CSV
class MeasurementHistoryPage extends StatefulWidget {
  const MeasurementHistoryPage({super.key});

  @override
  State<MeasurementHistoryPage> createState() => _MeasurementHistoryPageState();
}

class _MeasurementHistoryPageState extends State<MeasurementHistoryPage> {
  String _query = '';
  AlertStatus? _filter;
  DateRange _range = DateRange.all;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final c = context.colors;
    final now = appState.now();
    final all = appState.records;
    // ช่วงเวลากรองก่อน แล้วสรุปผลจากชุดนี้
    final inRange =
        all.where((r) => _range.contains(r.timestamp, now)).toList();
    final query = _query.trim().toLowerCase();
    final records =
        inRange.where((r) {
          if (_filter != null && r.alertStatus != _filter) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return r.name.toLowerCase().contains(query) ||
              r.licensePlate.toLowerCase().contains(query);
        }).toList();
    final summary = MeasurementSummary.of(inRange);

    // จัดกลุ่มตามวัน (records เรียงใหม่ → เก่าอยู่แล้ว)
    final groups = <List<MeasurementRecord>>[];
    for (final r in records) {
      if (groups.isEmpty ||
          !isSameDay(groups.last.first.timestamp, r.timestamp)) {
        groups.add([r]);
      } else {
        groups.last.add(r);
      }
    }

    return RefreshIndicator(
      onRefresh: appState.syncNow,
      child: PageBody(
        children: [
          PageHeader(
            'ประวัติ',
            trailing: Builder(
              builder:
                  (buttonContext) => OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed:
                        records.isEmpty || _exporting
                            ? null
                            : () => _export(records, _originOf(buttonContext)),
                    icon:
                        _exporting
                            ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.download_rounded, size: 20),
                    label: const Text('ส่งออก CSV'),
                  ),
            ),
          ),
          const SizedBox(height: 14),
          if (appState.hasCloud) ...[
            _SyncBanner(appState: appState),
            const SizedBox(height: 12),
          ],
          _RangeTabs(
            value: _range,
            onChanged: (range) => setState(() => _range = range),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        compact: true,
                        label: 'ตรวจ',
                        value: '${summary.total}',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        compact: true,
                        label: 'เกินเกณฑ์',
                        value:
                            summary.total == 0
                                ? '-'
                                : '${summary.count(AlertStatus.danger)}',
                        detail:
                            summary.total == 0
                                ? null
                                : '${(summary.ratio(AlertStatus.danger) * 100).round()}%',
                        status: AlertStatus.danger,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        compact: true,
                        label: 'เฉลี่ย',
                        value: summary.average?.toStringAsFixed(1) ?? '-',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        compact: true,
                        label: 'สูงสุด',
                        value: summary.max?.toStringAsFixed(1) ?? '-',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StatusRatioBar(counts: summary.counts),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    for (final s in AlertStatus.values)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: s.fill,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${s.label} ${summary.count(s)}',
                            style: TextStyle(fontSize: 13, color: c.muted),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'ค้นหาชื่อหรือทะเบียน',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 8),
              _StatusFilterButton(
                value: _filter,
                summary: summary,
                onChanged: (status) => setState(() => _filter = status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            _EmptyState(hasRecords: all.isNotEmpty)
          else
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  formatDayHeading(group.first.timestamp, now),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.muted,
                  ),
                ),
              ),
              GroupedList(
                children: [
                  for (final record in group)
                    RecordRow(
                      record: record,
                      subtitle:
                          '${record.licensePlate} ${record.province} · ${formatTime(record.timestamp)}',
                      onTap: () => _showDetails(context, record),
                      trailing:
                          appState.hasCloud && !record.synced
                              ? Tooltip(
                                message: 'ยังไม่ได้ส่งขึ้น cloud',
                                child: Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 16,
                                  color: c.muted,
                                ),
                              )
                              : null,
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }

  static Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // ส่งออกรายการที่แสดงอยู่ (ตามช่วงเวลา สถานะ และคำค้น) เป็น CSV
  Future<void> _export(List<MeasurementRecord> records, Rect? origin) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      await saveCsvFile(
        csv: buildMeasurementsCsv(records),
        fileName: csvFileName(DateTime.now()),
        shareOrigin: origin,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'ส่งออก ${records.length} รายการแล้ว (เลขบัตรประชาชนถูกปิดไว้)',
            ),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('ส่งออกไม่สำเร็จ: $e')));
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  // รายละเอียดเต็ม: เลขบัตรปิดไว้ก่อน กดเพื่อแสดง
  void _showDetails(BuildContext context, MeasurementRecord record) {
    final appState = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (sheetContext) => _RecordDetails(
            record: record,
            hasCloud: appState.hasCloud,
            onDelete: () async {
              final confirmed = await showDialog<bool>(
                context: sheetContext,
                builder:
                    (dialogContext) => AlertDialog(
                      title: const Text('ลบรายการนี้?'),
                      content: Text(
                        appState.hasCloud
                            ? 'ข้อมูลของ ${record.name} จะถูกลบจากเครื่องนี้และ cloud'
                            : 'ข้อมูลของ ${record.name} จะถูกลบจากเครื่องนี้',
                      ),
                      actions: [
                        TextButton(
                          onPressed:
                              () => Navigator.of(dialogContext).pop(false),
                          child: const Text('ยกเลิก'),
                        ),
                        TextButton(
                          onPressed:
                              () => Navigator.of(dialogContext).pop(true),
                          child: Text(
                            'ลบ',
                            style: TextStyle(
                              color: dialogContext.colors.dangerInk,
                            ),
                          ),
                        ),
                      ],
                    ),
              );
              if (confirmed != true || !sheetContext.mounted) {
                return;
              }
              Navigator.of(sheetContext).pop();
              await appState.removeRecord(record.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('ลบข้อมูลสำเร็จ')),
                  );
              }
            },
          ),
    );
  }
}

// แท็บเลือกช่วงเวลาแบบ segmented
class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.value, required this.onChanged});

  final DateRange value;
  final ValueChanged<DateRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFE7EAEE) : c.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final range in DateRange.values)
            Expanded(
              child: Semantics(
                selected: range == value,
                button: true,
                child: Material(
                  color: range == value ? c.surface : Colors.transparent,
                  elevation: range == value ? 1 : 0,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => onChanged(range),
                    child: SizedBox(
                      height: 38,
                      child: Center(
                        child: Text(
                          range.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                range == value
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                            color: range == value ? c.ink : c.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({
    required this.value,
    required this.summary,
    required this.onChanged,
  });

  final AlertStatus? value;
  final MeasurementSummary summary;
  final ValueChanged<AlertStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = value;
    final ink = selected == null ? c.ink : c.statusInk(selected);
    return PopupMenuButton<int>(
      tooltip: 'กรองตามสถานะ',
      onSelected: (i) => onChanged(i < 0 ? null : AlertStatus.values[i]),
      itemBuilder:
          (_) => [
            CheckedPopupMenuItem(
              value: -1,
              checked: selected == null,
              child: Text('ทุกสถานะ ${summary.total}'),
            ),
            for (final s in AlertStatus.values)
              CheckedPopupMenuItem(
                value: s.index,
                checked: selected == s,
                child: Text('${s.label} ${summary.count(s)}'),
              ),
          ],
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected == null ? c.surface : c.statusSoft(selected),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected == null
                    ? (Theme.of(context).brightness == Brightness.light
                        ? const Color(0xFFCBD2DC)
                        : c.border)
                    : ink,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded, size: 20, color: ink),
            const SizedBox(width: 6),
            Text(
              selected == null ? 'ทุกสถานะ' : selected.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pending = appState.pendingSyncCount;
    final error = appState.syncError;

    final (IconData icon, Color color, Color bg, String text) =
        appState.syncing
            ? (Icons.sync, c.primary, c.primarySoft, 'กำลังซิงก์กับ cloud…')
            : error != null
            ? (
              Icons.cloud_off_outlined,
              c.warningInk,
              c.warningSoft,
              pending > 0
                  ? 'ซิงก์ไม่สำเร็จ ค้างอยู่ $pending รายการ'
                  : 'ซิงก์ไม่สำเร็จ',
            )
            : pending > 0
            ? (
              Icons.cloud_upload_outlined,
              c.warningInk,
              c.warningSoft,
              'รอส่งขึ้น cloud $pending รายการ',
            )
            : (
              Icons.cloud_done_outlined,
              c.safeInk,
              c.safeSoft,
              'ซิงก์กับ cloud แล้ว',
            );

    return Tooltip(
      message: error ?? '',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(color: color, fontSize: 14)),
            ),
            TextButton(
              onPressed: appState.syncing ? null : appState.syncNow,
              child: const Text('ซิงก์ตอนนี้'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasRecords});

  final bool hasRecords;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            hasRecords ? Icons.search_off_rounded : Icons.history_rounded,
            size: 56,
            color: c.muted,
          ),
          const SizedBox(height: 12),
          Text(
            hasRecords ? 'ไม่พบรายการในช่วงนี้' : 'ยังไม่มีประวัติการตรวจ',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          Text(
            hasRecords
                ? 'ลองเปลี่ยนช่วงเวลา สถานะ หรือคำค้น'
                : 'เริ่มตรวจได้จากหน้าหลัก',
            style: TextStyle(color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _RecordDetails extends StatefulWidget {
  const _RecordDetails({
    required this.record,
    required this.hasCloud,
    required this.onDelete,
  });

  final MeasurementRecord record;
  final bool hasCloud;
  final VoidCallback onDelete;

  @override
  State<_RecordDetails> createState() => _RecordDetailsState();
}

class _RecordDetailsState extends State<_RecordDetails> {
  bool _showId = false;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final c = context.colors;
    final status = record.alertStatus;

    Widget row(String label, String value, {Widget? trailing}) => Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: c.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.ink,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.statusSoft(status),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusPill(status),
                      ],
                    ),
                  ),
                  Text(
                    record.alcoholValue.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: c.statusInk(status),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            row(
              'เลขบัตรประชาชน',
              _showId ? formatThaiId(record.idCard) : maskThaiId(record.idCard),
              // เลขเต็มของรายการที่ซิงก์แล้วไม่ได้เก็บในเครื่อง ต้องโหลดจาก cloud ก่อน
              trailing:
                  !hasFullThaiId(record.idCard)
                      ? Tooltip(
                        message: 'เชื่อมต่อ cloud เพื่อดูเลขเต็ม',
                        child: Icon(
                          Icons.cloud_off_outlined,
                          size: 20,
                          color: c.muted,
                        ),
                      )
                      : IconButton(
                        tooltip: _showId ? 'ซ่อนเลขบัตร' : 'แสดงเลขบัตร',
                        icon: Icon(
                          _showId
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() => _showId = !_showId),
                      ),
            ),
            row('อายุ', '${record.age} ปี'),
            row('ทะเบียนรถ', '${record.licensePlate} ${record.province}'),
            row('เวลา', formatThaiDateTime(record.timestamp)),
            row(
              'สถานะข้อมูล',
              !widget.hasCloud
                  ? 'เก็บในเครื่องนี้เท่านั้น'
                  : record.synced
                  ? 'ซิงก์กับ cloud แล้ว'
                  : 'รอส่งขึ้น cloud',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.dangerInk,
                side: BorderSide(color: c.dangerInk.withValues(alpha: 0.5)),
                minimumSize: const Size(0, 48),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('ลบรายการ'),
            ),
          ],
        ),
      ),
    );
  }
}
