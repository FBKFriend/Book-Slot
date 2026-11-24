import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_user.dart';
import '../../models/fine.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/fine_detail_body.dart';
import 'fine_detail_screen.dart';

/// The "Fines" tab inside the librarian's Borrowing screen.
class FinesList extends StatefulWidget {
  final List<Fine> fines;
  final AppUser user;
  const FinesList({super.key, required this.fines, required this.user});

  @override
  State<FinesList> createState() => _FinesListState();
}

class _FinesListState extends State<FinesList> {
  String _filter = 'unpaid'; // unpaid | paid | all

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final unpaid = widget.fines.where((f) => !f.isPaid).toList();
    final paid = widget.fines.where((f) => f.isPaid).toList();
    final shown = _filter == 'unpaid'
        ? unpaid
        : _filter == 'paid'
        ? paid
        : widget.fines;
    final unpaidTotal = unpaid.fold<int>(0, (s, f) => s + f.amount);

    return Column(
      children: [
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
        if (unpaid.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Unpaid total: ${formatPeso(unpaidTotal)}',
                style: t.bodySmall,
              ),
            ),
          ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    _filter == 'unpaid'
                        ? 'No unpaid fines'
                        : _filter == 'paid'
                        ? 'No paid fines yet'
                        : 'No fines yet',
                    style: t.bodySmall,
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
                          builder: (_) =>
                              FineDetailScreen(fine: f, user: widget.user),
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
    final student = f.studentName.isEmpty ? f.studentEmail : f.studentName;
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
                      student,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.heading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f.createdAt == null
                          ? f.reasonLabel
                          : '${f.reasonLabel}  ·  ${formatDate(f.createdAt!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
