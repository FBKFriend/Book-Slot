import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

Future<DateTimeRange?> showGoldDateRangePicker(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialRange,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _GoldRangeDialog(
      firstDate: firstDate,
      lastDate: lastDate,
      initialRange: initialRange,
    ),
  );
}

class _GoldRangeDialog extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialRange;

  const _GoldRangeDialog({
    required this.firstDate,
    required this.lastDate,
    this.initialRange,
  });

  @override
  State<_GoldRangeDialog> createState() => _GoldRangeDialogState();
}

class _GoldRangeDialogState extends State<_GoldRangeDialog> {
  static const double _cellHeight = 40;
  static const double _dot = 34;

  late final DateTime _first = _day(widget.firstDate);
  late final DateTime _last = _day(widget.lastDate);
  late DateTime _month;
  DateTime? _start;
  DateTime? _end;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    final init = widget.initialRange;
    _start = init == null ? null : _day(init.start);
    _end = init == null ? null : _day(init.end);
    final anchor = _start ?? _last;
    _month = DateTime(anchor.year, anchor.month, 1);
  }

  bool get _canPrev => DateTime(_month.year, _month.month, 1)
      .isAfter(DateTime(_first.year, _first.month, 1));

  bool get _canNext => DateTime(_month.year, _month.month, 1)
      .isBefore(DateTime(_last.year, _last.month, 1));

  void _tap(DateTime d) {
    setState(() {
      if (_start == null || _end != null) {
        _start = d;
        _end = null;
      } else if (d.isBefore(_start!)) {
        _end = _start;
        _start = d;
      } else {
        _end = d;
      }
    });
  }

  Widget _cell(DateTime? d) {
    if (d == null) return const SizedBox(height: _cellHeight);

    final enabled = !d.isBefore(_first) && !d.isAfter(_last);
    final isStart = _start != null && _same(d, _start!);
    final isEnd = _end != null && _same(d, _end!);
    final hasSpan = _start != null && _end != null && !_same(_start!, _end!);
    final inside = hasSpan && d.isAfter(_start!) && d.isBefore(_end!);
    final selected = isStart || isEnd;
    final isToday = _same(d, _day(DateTime.now()));

    const line = BorderSide(color: AppColors.gold, width: 1);
    const bandDecoration =
        BoxDecoration(border: Border(top: line, bottom: line));
    final bandLeft = hasSpan && (inside || isEnd);
    final bandRight = hasSpan && (inside || isStart);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _tap(d) : null,
      child: SizedBox(
        height: _cellHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thin gold lines (top and bottom) connecting the two dates
            if (bandLeft || bandRight)
              SizedBox(
                height: _dot,
                child: Row(
                  children: [
                    Expanded(
                      child: bandLeft
                          ? const DecoratedBox(decoration: bandDecoration)
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: bandRight
                          ? const DecoratedBox(decoration: bandDecoration)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            Container(
              width: _dot,
              height: _dot,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.gold : null,
                border: (!selected && isToday)
                    ? Border.all(color: AppColors.border)
                    : null,
              ),
              child: Text(
                '${d.day}',
                style: TextStyle(
                  color: selected
                      ? AppColors.background
                      : (enabled
                          ? AppColors.heading
                          : AppColors.muted.withValues(alpha: 0.4)),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = firstOfMonth.weekday - 1; // Monday first
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(_month.year, _month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final rows = <Widget>[
      for (var i = 0; i < cells.length; i += 7)
        Row(
          children: [
            for (final c in cells.sublist(i, i + 7)) Expanded(child: _cell(c)),
          ],
        ),
    ];

    final summary = _start == null
        ? 'Tap a start date'
        : _end == null
            ? '${formatDate(_start!)} · tap an end date, or Save for one day'
            : '${formatDate(_start!)} – ${formatDate(_end!)}';

    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select dates', style: t.titleLarge),
            const SizedBox(height: 6),
            Text(summary, style: t.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _canPrev
                      ? () => setState(() => _month =
                          DateTime(_month.year, _month.month - 1, 1))
                      : null,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_monthNames[_month.month - 1]} ${_month.year}',
                      style: const TextStyle(
                        color: AppColors.heading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _canNext
                      ? () => setState(() => _month =
                          DateTime(_month.year, _month.month + 1, 1))
                      : null,
                ),
              ],
            ),
            Row(
              children: [
                for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(child: Center(child: Text(w, style: t.bodySmall))),
              ],
            ),
            const SizedBox(height: 4),
            ...rows,
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _start == null
                      ? null
                      : () => Navigator.pop(
                            context,
                            DateTimeRange(start: _start!, end: _end ?? _start!),
                          ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}