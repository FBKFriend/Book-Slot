import 'package:flutter/material.dart';

import '../../models/audit_entry.dart';
import '../../services/audit_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_range.dart';
import '../../utils/format.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/gold_range_picker.dart';
import 'print_audit_screen.dart';

class AuditTab extends StatefulWidget {
  const AuditTab({super.key});

  @override
  State<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<AuditTab> {
  static const _limit = 200;

  String _entity = 'all';
  String _preset = 'all';
  DateTimeRange? _custom;
  late Stream<List<AuditEntry>> _stream = _buildStream();

  Stream<List<AuditEntry>> _buildStream() {
    final r = resolveRange(_preset, from: _custom?.start, to: _custom?.end);
    return AuditService.instance.watchRange(
      start: r.start,
      endExclusive: r.endExclusive,
      limit: _limit,
    );
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showGoldDateRangePicker(
      context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      initialRange: _custom,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _preset = 'custom';
      _custom = picked;
      _stream = _buildStream();
    });
  }

  void _onPreset(String v) {
    if (v == 'custom') {
      _pickCustom();
      return;
    }
    setState(() {
      _preset = v;
      _stream = _buildStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            tooltip: 'Print PDF',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PrintAuditScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterDropdown(
                    label: 'Show',
                    value: _entity,
                    options: kAuditActorOptions,
                    onChanged: (v) => setState(() => _entity = v),
                  ),
                  FilterDropdown(
                    label: 'Date',
                    value: _preset,
                    options: kDatePresetOptions,
                    onChanged: _onPreset,
                  ),
                ],
              ),
            ),
          ),
          if (_preset == 'custom' && _custom != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _pickCustom,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(
                    '${formatDate(_custom!.start)} – ${formatDate(_custom!.end)}',
                  ),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<AuditEntry>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Could not load the logs.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                final entries = _entity == 'all'
                    ? all
                    : all.where((e) => e.actorRole == _entity).toList();
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      all.isEmpty
                          ? 'No log entries for this period'
                          : 'No entries for this filter',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                final showNote = all.length >= _limit;
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length + (showNote ? 1 : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == entries.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Showing the latest $_limit entries. Narrow the dates, or use Print PDF for the full list.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }
                    return _AuditCard(entries[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AuditEntry e;
  const _AuditCard(this.e);

  static IconData _icon(String action) {
    switch (action) {
      case 'account.authorize':
        return Icons.verified_user_outlined;
      case 'account.reject':
        return Icons.person_off_outlined;
      case 'account.suspend':
        return Icons.block;
      case 'account.reactivate':
        return Icons.restart_alt;
      case 'account.add_librarian':
        return Icons.person_add_alt_1_outlined;
      case 'account.edit':
        return Icons.edit_outlined;
      case 'account.role_change':
        return Icons.swap_horiz;
      case 'settings.update':
        return Icons.tune;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final title = auditActionTitle(e.action);
    final icon = _icon(e.action);
    final actor = e.actorName.isEmpty ? e.actorEmail : e.actorName;
    final hasName = (e.targetName ?? '').isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.background,
              child: Icon(icon, color: AppColors.gold, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'By $actor (${e.actorRole})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall,
                  ),
                  if (e.targetEmail != null) ...[
                    Text(
                      hasName
                          ? 'Account: ${e.targetName}'
                          : 'Account: ${e.targetEmail}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall,
                    ),
                    if (hasName)
                      Text(
                        e.targetEmail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
                  ],
                  if ((e.details ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(e.details!),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    e.createdAt == null
                        ? 'Just now'
                        : formatDateTime(e.createdAt!),
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
