import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/dashboard_stats.dart';
import '../../services/dashboard_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late final Stream<UserCounts> _stream = UserService.instance
      .watchUserCounts();

  DashboardStats? _stats; // null until the first numbers arrive
  StreamSubscription<DashboardStats>? _statsSub;

  @override
  void initState() {
    super.initState();
    _statsSub = DashboardService.instance.watch().listen((s) {
      if (mounted) setState(() => _stats = s);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Dashboard')),
      body: StreamBuilder<UserCounts>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load the dashboard.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = snap.data!;
          final s = _stats;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (c.pending > 0) ...[
                _PendingBanner(count: c.pending),
                const SizedBox(height: 12),
              ],
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _StatCard(
                    icon: Icons.school_outlined,
                    label: 'Registered students',
                    value: '${c.students}',
                  ),
                  _StatCard(
                    icon: Icons.local_library_outlined,
                    label: 'Librarians',
                    value: '${c.librarians}',
                  ),
                  _StatCard(
                    icon: Icons.menu_book_outlined,
                    label: 'Books in library',
                    value: s == null ? null : '${s.titles}',
                    caption: s == null
                        ? null
                        : '${s.totalCopies} ${s.totalCopies == 1 ? 'copy' : 'copies'}',
                  ),
                  _StatCard(
                    icon: Icons.swap_horiz,
                    label: 'Active borrowings',
                    value: s == null ? null : '${s.borrowedNow}',
                  ),
                  _StatCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'Overdue borrowings',
                    value: s == null ? null : '${s.overdue}',
                  ),
                  _StatCard(
                    icon: Icons.calendar_month_outlined,
                    label: 'Borrowed this month',
                    value: s == null ? null : '${s.borrowedThisMonth}',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value; // null = not available yet
  final String? caption; // small line under the label

  const _StatCard({
    required this.icon,
    required this.label,
    this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.gold, size: 22),
            const Spacer(),
            Text(
              value ?? '—',
              style: GoogleFonts.playfairDisplay(
                color: AppColors.heading,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (caption != null)
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  final int count;
  const _PendingBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count registration${count == 1 ? '' : 's'} waiting for approval. Review ${count == 1 ? 'it' : 'them'} in the Users tab.',
            ),
          ),
        ],
      ),
    );
  }
}
