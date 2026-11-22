import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_range.dart';
import '../../utils/format.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/gold_range_picker.dart';

class StudentHistoryScreen extends StatefulWidget {
  final AppUser user;
  const StudentHistoryScreen({super.key, required this.user});

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  static const _typeOptions = {
    'all': 'All',
    'current': 'Active now',
    'returned': 'Returned',
    'closed': 'Cancelled / denied / expired',
  };

  late final Stream<List<Reservation>> _stream = ReservationService.instance
      .watchForStudent(widget.user.email);
  final _search = TextEditingController();
  String _query = '';
  String _type = 'all';
  String _preset = 'all';
  DateTimeRange? _custom;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
    });
  }

  void _onPreset(String v) {
    if (v == 'custom') {
      _pickCustom();
      return;
    }
    setState(() => _preset = v);
  }

  bool _matchesType(Reservation r) {
    switch (_type) {
      case 'current':
        return r.status == 'pending' ||
            r.status == 'accepted' ||
            r.status == 'picked_up';
      case 'returned':
        return r.status == 'returned';
      case 'closed':
        return const {
          'denied',
          'expired',
          'dropped',
          'cancelled',
        }.contains(r.status);
      default:
        return true;
    }
  }

  bool _matches(Reservation r, DateBounds range, String q) {
    if (!_matchesType(r)) return false;

    // Pending writes have no date yet; they count as "now"
    final d = r.createdAt ?? DateTime.now();
    if (range.start != null && d.isBefore(range.start!)) return false;
    if (range.endExclusive != null && !d.isBefore(range.endExclusive!)) {
      return false;
    }

    if (q.isEmpty) return true;
    return r.bookTitle.toLowerCase().contains(q) ||
        r.bookId.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();
    final range = resolveRange(_preset, from: _custom?.start, to: _custom?.end);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search book title or ID',
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
            child: StreamBuilder<List<Reservation>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Could not load history.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                if (all.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No history yet. Reserve a book from the Menu to get started.',
                        textAlign: TextAlign.center,
                        style: t.bodySmall,
                      ),
                    ),
                  );
                }
                final entries = all
                    .where((r) => _matches(r, range, q))
                    .toList();
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      'No records match your filters',
                      style: t.bodySmall,
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        '${entries.length} ${entries.length == 1 ? 'record' : 'records'}',
                        style: t.bodySmall,
                      );
                    }
                    return _HistoryCard(entries[i - 1]);
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
  final Reservation r;
  const _HistoryCard(this.r);

  static const _green = Color(0xFF7FB77E);
  static const _red = Color(0xFFE57373);

  (String, Color) get _look {
    switch (r.status) {
      case 'pending':
        return ('Pending', AppColors.gold);
      case 'accepted':
        return ('Approved', _green);
      case 'denied':
        return ('Denied', _red);
      case 'expired':
        return ('Expired', AppColors.muted);
      case 'dropped':
        return ('Dropped', AppColors.muted);
      case 'cancelled':
        return ('Cancelled', AppColors.muted);
      case 'picked_up':
        return ('Borrowed', AppColors.gold);
      case 'returned':
        return ('Returned', _green);
      default:
        return (r.status, AppColors.muted);
    }
  }

  List<String> _lines() {
    final lines = <String>[];
    lines.add(
      r.createdAt == null
          ? 'Reserved: just now'
          : 'Reserved: ${formatDateTime(r.createdAt!)}',
    );

    final decided = r.decidedAt;
    if (decided != null) {
      lines.add(
        r.status == 'denied'
            ? 'Denied: ${formatDateTime(decided)}'
            : 'Approved: ${formatDateTime(decided)}',
      );
    }
    if (r.status == 'accepted' && r.pickupDeadline != null) {
      lines.add('Pick up by: ${formatDate(r.pickupDeadline!)}');
    }
    if (r.pickedUpAt != null) {
      lines.add('Picked up: ${formatDateTime(r.pickedUpAt!)}');
    }
    final due = r.dueAt;
    if (due != null && (r.status == 'picked_up' || r.status == 'returned')) {
      final overdue = r.status == 'picked_up' && due.isBefore(DateTime.now());
      lines.add('Due: ${formatDate(due)}${overdue ? ' (overdue)' : ''}');
    }
    final returned = r.returnedAt;
    if (returned != null) {
      final late = due != null && returned.isAfter(due);
      lines.add(
        'Returned: ${formatDateTime(returned)}${late ? ' (late)' : ''}',
      );
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (label, color) = _look;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    r.bookTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _Pill(label: label, color: color),
              ],
            ),
            const SizedBox(height: 2),
            Text(r.bookId, style: t.bodySmall),
            const SizedBox(height: 10),
            for (final line in _lines())
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(line, style: t.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
