import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/fine.dart';
import '../../services/fine_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/fine_detail_body.dart';

/// The "Fines" tab inside the student's Alerts screen.
class StudentFinesList extends StatefulWidget {
  final List<Fine>? fines; // null = still loading
  final bool hasError;
  const StudentFinesList({
    super.key,
    required this.fines,
    required this.hasError,
  });

  @override
  State<StudentFinesList> createState() => _StudentFinesListState();
}

class _StudentFinesListState extends State<StudentFinesList> {
  String _filter = 'unpaid'; // unpaid | paid | all

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (widget.hasError) {
      return const Center(child: Text('Could not load your fines.'));
    }
    final all = widget.fines;
    if (all == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final unpaid = all.where((f) => !f.isPaid).toList();
    final paid = all.where((f) => f.isPaid).toList();
    final shown = _filter == 'unpaid'
        ? unpaid
        : _filter == 'paid'
        ? paid
        : all;
    final unpaidTotal = unpaid.fold<int>(0, (s, f) => s + f.amount);

    return Column(
      children: [
        if (unpaid.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE57373)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFE57373),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You owe ${formatPeso(unpaidTotal)}. Reserving and picking up books is paused until you settle it at the library.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                for (final o in [
                  ('unpaid', 'Unpaid (${unpaid.length})'),
                  ('paid', 'Paid (${paid.length})'),
                  ('all', 'All'),
                ])
                  ChoiceChip(
                    label: Text(o.$2),
                    selected: _filter == o.$1,
                    selectedColor: AppColors.gold.withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _filter = o.$1),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _filter == 'unpaid'
                          ? 'You have no unpaid fines.'
                          : _filter == 'paid'
                          ? 'No paid fines yet.'
                          : 'You have no fines.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: shown.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final f = shown[i];
                    return _FineCard(
                      fine: f,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentFineDetailScreen(fine: f),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FineCard extends StatelessWidget {
  final Fine fine;
  final VoidCallback onTap;
  const _FineCard({required this.fine, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = fine;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.background,
                child: Icon(
                  f.damaged ? Icons.report_problem_outlined : Icons.schedule,
                  color: AppColors.gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.bookTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.heading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f.reasonLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f.createdAt == null
                          ? 'Just now'
                          : formatDate(f.createdAt!),
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPeso(f.amount),
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FineStatusPill(paid: f.isPaid),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentFineDetailScreen extends StatefulWidget {
  final Fine fine;
  const StudentFineDetailScreen({super.key, required this.fine});

  @override
  State<StudentFineDetailScreen> createState() =>
      _StudentFineDetailScreenState();
}

class _StudentFineDetailScreenState extends State<StudentFineDetailScreen> {
  late final Stream<Fine?> _stream = FineService.instance.watchFine(
    widget.fine.id,
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<Fine?>(
      stream: _stream,
      initialData: widget.fine,
      builder: (context, snap) {
        final appBar = AppBar(title: const Text('Fine details'));
        final f = snap.data;
        if (f == null) {
          return Scaffold(
            appBar: appBar,
            body: const Center(child: Text('This fine no longer exists.')),
          );
        }
        return Scaffold(
          appBar: appBar,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FineDetailBody(fine: f),
              if (!f.isPaid) ...[
                const SizedBox(height: 20),
                Text(
                  'Please settle this fine at the library. Once it is marked as paid, you can reserve and pick up books again.',
                  textAlign: TextAlign.center,
                  style: t.bodySmall,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
