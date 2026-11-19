import 'package:flutter/material.dart';

import '../../models/history_entry.dart';
import '../../services/borrowing_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_range.dart';
import '../../utils/format.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/gold_range_picker.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  static const _limit = 200;
  static const _typeOptions = {
    'all': 'All',
    'borrow': 'Borrowed',
    'return': 'Returned',
  };

  final _search = TextEditingController();
  String _query = '';
  String _type = 'all';
  String _preset = 'all';
  DateTimeRange? _custom;
  late Stream<List<HistoryEntry>> _stream = _buildStream();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<List<HistoryEntry>> _buildStream() {
    final r = resolveRange(_preset, from: _custom?.start, to: _custom?.end);
    return BorrowingService.instance.watchHistory(
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

  bool _matches(HistoryEntry e, String q) {
    if (_type != 'all' && e.type != _type) return false;
    if (q.isEmpty) return true;
    return e.studentName.toLowerCase().contains(q) ||
        (e.studentId ?? '').toLowerCase().contains(q) ||
        e.studentEmail.toLowerCase().contains(q) ||
        e.bookTitle.toLowerCase().contains(q) ||
        e.bookId.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search student, ID, or book',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterDropdown(
                    label: 'Show',
                    value: _type,
                    options: _typeOptions,
                    onChanged: (v) => setState(() => _type = v),
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
            child: StreamBuilder<List<HistoryEntry>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Could not load history.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                final entries = all.where((e) => _matches(e, q)).toList();
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      all.isEmpty
                          ? 'No transactions for this period'
                          : 'No transactions match your filters',
                      style: t.bodySmall,
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
                          'Showing the latest $_limit transactions. Narrow the dates to see older ones.',
                          textAlign: TextAlign.center,
                          style: t.bodySmall,
                        ),
                      );
                    }
                    return _HistoryCard(entries[i]);
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

class _HistoryCard extends StatelessWidget {
  final HistoryEntry e;
  const _HistoryCard(this.e);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isBorrow = e.type == 'borrow';
    final student = e.studentName.isEmpty ? e.studentEmail : e.studentName;
    final studentLine = (e.studentId ?? '').isEmpty
        ? student
        : '$student (${e.studentId})';
    final staff = e.staffName.isEmpty ? e.staffEmail : e.staffName;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.background,
              child: Icon(
                isBorrow ? Icons.north_east : Icons.south_west,
                color: AppColors.gold,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isBorrow ? 'Borrowed' : 'Returned',
                        style: const TextStyle(
                          color: AppColors.heading,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isBorrow && e.overdue) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Late',
                          style: TextStyle(
                            color: Color(0xFFE57373),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.bookTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(color: AppColors.heading),
                  ),
                  Text(e.bookId, style: t.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    studentLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall,
                  ),
                  if (isBorrow && e.dueAt != null)
                    Text('Due ${formatDate(e.dueAt!)}', style: t.bodySmall),
                  Text(
                    'Handled by $staff',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall,
                  ),
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
