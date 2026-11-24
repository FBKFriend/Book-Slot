import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/fine.dart';
import '../services/fine_service.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';

class FineStatusPill extends StatelessWidget {
  final bool paid;
  const FineStatusPill({super.key, required this.paid});

  @override
  Widget build(BuildContext context) {
    final color = paid ? const Color(0xFF7FB77E) : const Color(0xFFE57373);
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
          Text(
            paid ? 'Paid' : 'Unpaid',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// The details of one fine. Staff also see who it was for and who handled it.
class FineDetailBody extends StatelessWidget {
  final Fine fine;
  final bool showStaffInfo;
  const FineDetailBody({
    super.key,
    required this.fine,
    this.showStaffInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = fine;
    final student = f.studentName.isEmpty ? f.studentEmail : f.studentName;
    final studentSub = [
      if ((f.studentId ?? '').isNotEmpty) f.studentId!,
      f.studentEmail,
    ].join('  ·  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                formatPeso(f.amount),
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.gold,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              FineStatusPill(paid: f.isPaid),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Row('Book', '${f.bookTitle}\n${f.bookId}'),
                if (showStaffInfo) _Row('Student', '$student\n$studentSub'),
                _Row(
                  'Reason',
                  f.wasLate
                      ? '${f.reasonLabel}\n${f.daysLate} ${f.daysLate == 1 ? 'day' : 'days'} late'
                      : f.reasonLabel,
                ),
                _Row(
                  'Date',
                  f.createdAt == null
                      ? 'Just now'
                      : formatDateTime(f.createdAt!),
                ),
                if (showStaffInfo && f.createdByName.isNotEmpty)
                  _Row('Fined by', f.createdByName),
                if (f.isPaid && f.paidAt != null)
                  _Row('Paid on', formatDateTime(f.paidAt!)),
                if (showStaffInfo && f.isPaid && f.paidByName.isNotEmpty)
                  _Row('Received by', f.paidByName),
              ],
            ),
          ),
        ),
        if (f.damaged) ...[
          const SizedBox(height: 16),
          Text('Damage report', style: t.titleLarge),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Row(
                    'What happened',
                    f.damageReason.isEmpty ? '—' : f.damageReason,
                  ),
                  _Row(
                    'Condition',
                    f.discarded
                        ? 'To be discarded (removed from the library)'
                        : 'Still functional',
                  ),
                ],
              ),
            ),
          ),
          if (f.hasPhoto) ...[
            const SizedBox(height: 12),
            FinePhoto(fineId: f.id),
          ],
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// The damage photo. Tap it to see it full screen.
class FinePhoto extends StatefulWidget {
  final String fineId;
  const FinePhoto({super.key, required this.fineId});

  @override
  State<FinePhoto> createState() => _FinePhotoState();
}

class _FinePhotoState extends State<FinePhoto> {
  late final Future<Uint8List?> _future = FineService.instance.loadPhoto(
    widget.fineId,
  );

  void _open(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Center(child: Image.memory(bytes)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
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
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final bytes = snap.data;
        if (bytes == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Photo not available',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () => _open(bytes),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}
