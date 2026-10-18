import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'device_reading.dart';
import 'thai_id.dart';
import 'theme.dart';
import 'widgets/common.dart';

class MeasurementHistoryPage extends StatefulWidget {
  const MeasurementHistoryPage({super.key});

  @override
  State<MeasurementHistoryPage> createState() => _MeasurementHistoryPageState();
}

class _MeasurementHistoryPageState extends State<MeasurementHistoryPage> {
  String _query = '';
  AlertStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final all = appState.records;
    final query = _query.trim().toLowerCase();
    final records =
        all.where((r) {
          if (_filter != null && r.alertStatus != _filter) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return r.name.toLowerCase().contains(query) ||
              r.licensePlate.toLowerCase().contains(query);
        }).toList();

    int count(AlertStatus status) =>
        all.where((r) => r.alertStatus == status).length;

    return RefreshIndicator(
      onRefresh: appState.syncNow,
      child: PageBody(
        children: [
          if (appState.hasCloud) ...[
            _SyncBanner(appState: appState),
            const SizedBox(height: 12),
          ],
          TextField(
            decoration: const InputDecoration(
              hintText: 'ค้นหาชื่อหรือทะเบียนรถ',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('ทั้งหมด ${all.length}'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final status in AlertStatus.values)
                ChoiceChip(
                  avatar: Icon(status.icon, size: 18, color: status.color),
                  label: Text('${status.label} ${count(status)}'),
                  selected: _filter == status,
                  onSelected:
                      (selected) =>
                          setState(() => _filter = selected ? status : null),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            _EmptyState(hasRecords: all.isNotEmpty)
          else
            for (final record in records) ...[
              _RecordTile(record: record),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final pending = appState.pendingSyncCount;
    final error = appState.syncError;
    final theme = Theme.of(context);

    final (IconData icon, Color color, String text) =
        appState.syncing
            ? (Icons.sync, theme.colorScheme.primary, 'กำลังซิงก์กับ cloud…')
            : error != null
            ? (
              Icons.cloud_off_outlined,
              AlertStatus.warning.color,
              pending > 0
                  ? 'ซิงก์ไม่สำเร็จ ค้างอยู่ $pending รายการ: $error'
                  : 'ซิงก์ไม่สำเร็จ: $error',
            )
            : pending > 0
            ? (
              Icons.cloud_upload_outlined,
              AlertStatus.warning.color,
              'รอส่งขึ้น cloud $pending รายการ',
            )
            : (
              Icons.cloud_done_outlined,
              AlertStatus.safe.color,
              'ซิงก์กับ cloud แล้ว',
            );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color))),
          TextButton(
            onPressed: appState.syncing ? null : appState.syncNow,
            child: const Text('ซิงก์ตอนนี้'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasRecords});

  final bool hasRecords;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            hasRecords ? Icons.search_off : Icons.history,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            hasRecords ? 'ไม่พบรายการที่ค้นหา' : 'ยังไม่มีประวัติการตรวจ',
            style: theme.textTheme.titleMedium,
          ),
          if (!hasRecords)
            Text(
              'บันทึกผลตรวจได้ที่แท็บตรวจวัด',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final MeasurementRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = record.alertStatus;
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final hasCloud = context.select<AppState, bool>((s) => s.hasCloud);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context, record),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  record.alcoholValue.toStringAsFixed(0),
                  style: TextStyle(
                    color: status.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.licensePlate} · ${record.province}',
                      style: muted,
                    ),
                    Text(formatThaiDateTime(record.timestamp), style: muted),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(status),
                  if (hasCloud && !record.synced) ...[
                    const SizedBox(height: 6),
                    Tooltip(
                      message: 'ยังไม่ได้ส่งขึ้น cloud',
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        size: 18,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AlertStatus.danger.color,
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed:
                              () => Navigator.of(dialogContext).pop(true),
                          child: const Text('ลบ'),
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
    final theme = Theme.of(context);

    Widget row(String label, String value, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
          if (trailing != null) trailing,
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusPill(record.alertStatus, large: true),
              ],
            ),
            const SizedBox(height: 12),
            row('ค่าที่วัดได้', record.alcoholValue.toStringAsFixed(1)),
            row(
              'เลขบัตรประชาชน',
              _showId ? formatThaiId(record.idCard) : maskThaiId(record.idCard),
              trailing: IconButton(
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
              icon: Icon(Icons.delete_outline, color: AlertStatus.danger.color),
              label: Text(
                'ลบรายการ',
                style: TextStyle(color: AlertStatus.danger.color),
              ),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ],
        ),
      ),
    );
  }
}
