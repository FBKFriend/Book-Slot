import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/report_data.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_range.dart';
import '../../utils/format.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/gold_range_picker.dart';

const _green = Color(0xFF7FB77E);
const _red = Color(0xFFE57373);

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  static const _periods = {
    'week': 'This week',
    'month': 'This month',
    '30d': 'Last 30 days',
    'year': 'This year',
    'all': 'All time',
    'custom': 'Custom',
  };

  String _preset = 'month';
  DateTimeRange? _custom;
  late Future<ReportData> _future = _load();

  DateBounds _bounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    switch (_preset) {
      case 'week':
        return (
          start: DateTime(
            today.year,
            today.month,
            today.day - (today.weekday - 1),
          ),
          endExclusive: tomorrow,
        );
      case 'month':
        return (
          start: DateTime(today.year, today.month, 1),
          endExclusive: tomorrow,
        );
      case '30d':
        return (
          start: DateTime(today.year, today.month, today.day - 29),
          endExclusive: tomorrow,
        );
      case 'year':
        return (start: DateTime(today.year, 1, 1), endExclusive: tomorrow);
      case 'custom':
        final c = _custom;
        if (c == null) return (start: null, endExclusive: null);
        return (
          start: DateTime(c.start.year, c.start.month, c.start.day),
          endExclusive: DateTime(c.end.year, c.end.month, c.end.day + 1),
        );
      default:
        return (start: null, endExclusive: null);
    }
  }

  String _periodLabel() {
    final b = _bounds();
    if (b.start == null || b.endExclusive == null) return 'All time';
    final last = DateTime(
      b.endExclusive!.year,
      b.endExclusive!.month,
      b.endExclusive!.day - 1,
    );
    final a = formatDate(b.start!);
    final z = formatDate(last);
    return a == z ? a : '$a – $z';
  }

  Future<ReportData> _load() {
    final b = _bounds();
    return ReportService.instance.build(
      start: b.start,
      endExclusive: b.endExclusive,
    );
  }

  void _reload() => setState(() => _future = _load());

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
      _future = _load();
    });
  }

  void _onPreset(String v) {
    if (v == 'custom') {
      _pickCustom();
      return;
    }
    setState(() {
      _preset = v;
      _future = _load();
    });
  }

  String _pct(double? v) => v == null ? '—' : '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterDropdown(
                label: 'Period',
                value: _preset,
                options: _periods,
                onChanged: _onPreset,
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
                  label: Text(_periodLabel()),
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<ReportData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not build the report.'),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  );
                }
                final d = snap.data!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text('Showing: ${_periodLabel()}', style: t.bodySmall),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        _Metric(
                          icon: Icons.north_east,
                          label: 'Books borrowed',
                          value: '${d.borrowed}',
                        ),
                        _Metric(
                          icon: Icons.south_west,
                          label: 'Books returned',
                          value: '${d.returned}',
                        ),
                        _Metric(
                          icon: Icons.bookmark_added_outlined,
                          label: 'Reservations made',
                          value: '${d.reservationsMade}',
                        ),
                        _Metric(
                          icon: Icons.task_alt,
                          label: 'Pickup rate',
                          value: _pct(d.pickupRate),
                          caption:
                              '${d.pickedUp} of ${d.pickedUp + d.expiredReservations} approved collected',
                        ),
                        _Metric(
                          icon: Icons.warning_amber_rounded,
                          label: 'Late returns',
                          value: _pct(d.lateRate),
                          caption: '${d.lateReturns} of ${d.returned} returned',
                        ),
                        _Metric(
                          icon: Icons.timer_outlined,
                          label: 'Avg. days kept',
                          value: d.avgDaysKept == null
                              ? '—'
                              : d.avgDaysKept!.toStringAsFixed(1),
                        ),
                        _Metric(
                          icon: Icons.groups_outlined,
                          label: 'Active readers',
                          value: '${d.activeReaders}',
                        ),
                        _Metric(
                          icon: Icons.menu_book_outlined,
                          label: 'Titles not borrowed',
                          value: '${d.titlesNotBorrowed}',
                          caption: 'of ${d.totalTitles} titles',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _Section(
                      title: 'Borrowing activity',
                      child: _TrendChart(points: d.trend),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Most borrowed books',
                      child: _RankList(
                        items: d.topBooks,
                        empty: 'No borrows in this period',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Popular genres',
                      child: _RankList(
                        items: d.topGenres,
                        empty: 'No borrows in this period',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Most active readers',
                      child: _RankList(
                        items: d.topReaders,
                        empty: 'No borrows in this period',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Borrows by course',
                      child: _RankList(
                        items: d.byCourse,
                        empty: 'No borrows in this period',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Reservation outcomes',
                      child: _RankList(
                        items: d.reservationOutcomes,
                        empty: 'No reservations in this period',
                        numbered: false,
                        colorFor: (i) {
                          switch (i.label) {
                            case 'Borrowed':
                            case 'Approved (waiting)':
                              return _green;
                            case 'Denied':
                              return _red;
                            case 'Pending':
                              return AppColors.gold;
                            default:
                              return AppColors.muted;
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.playfairDisplay(
                color: AppColors.heading,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall,
            ),
            if (caption != null)
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  const _TrendChart({required this.points});

  static const _height = 150.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final maxV = points.fold<int>(
      0,
      (m, p) => max(m, max(p.borrowed, p.returned)),
    );
    if (points.isEmpty || maxV == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No borrowing activity in this period',
            style: t.bodySmall,
          ),
        ),
      );
    }

    final n = points.length;
    final every = n <= 12 ? 1 : (n <= 24 ? 3 : 5);

    Widget bar(double w, double h, Color color) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _Legend(color: AppColors.gold, label: 'Borrowed'),
            const SizedBox(width: 16),
            const _Legend(color: _green, label: 'Returned'),
            const Spacer(),
            Text('Peak: $maxV', style: t.bodySmall),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final slot = c.maxWidth / n;
            final barW = ((slot - 3) / 2).clamp(2.0, 14.0).toDouble();
            double h(int v) => v == 0 ? 0 : max(2.0, _height * v / maxV);

            return Column(
              children: [
                SizedBox(
                  height: _height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final p in points)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              bar(barW, h(p.borrowed), AppColors.gold),
                              const SizedBox(width: 1),
                              bar(barW, h(p.returned), _green),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: Text(
                          i % every == 0 ? points[i].label : '',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: t.bodySmall?.copyWith(fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RankList extends StatelessWidget {
  final List<RankItem> items;
  final String empty;
  final bool numbered;
  final Color Function(RankItem item)? colorFor;
  const _RankList({
    required this.items,
    required this.empty,
    this.numbered = true,
    this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (items.isEmpty) return Text(empty, style: t.bodySmall);

    final maxC = items.fold<int>(1, (m, i) => max(m, i.count));
    final indent = numbered ? 22.0 : 0.0;

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (numbered)
                      SizedBox(
                        width: indent,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        items[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.heading),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${items[i].count}',
                      style: const TextStyle(
                        color: AppColors.heading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if ((items[i].sub ?? '').isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: indent),
                    child: Text(items[i].sub!, style: t.bodySmall),
                  ),
                const SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.only(left: indent),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: items[i].count / maxC,
                      minHeight: 6,
                      backgroundColor: AppColors.background,
                      color: colorFor?.call(items[i]) ?? AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
