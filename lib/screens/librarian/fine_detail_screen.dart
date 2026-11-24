import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/fine.dart';
import '../../services/fine_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/fine_detail_body.dart';

class FineDetailScreen extends StatefulWidget {
  final Fine fine;
  final AppUser user;
  const FineDetailScreen({super.key, required this.fine, required this.user});

  @override
  State<FineDetailScreen> createState() => _FineDetailScreenState();
}

class _FineDetailScreenState extends State<FineDetailScreen> {
  late final Stream<Fine?> _stream = FineService.instance.watchFine(
    widget.fine.id,
  );
  bool _busy = false;

  Future<void> _markPaid(Fine f) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as paid?'),
        content: Text(
          '${f.studentName} paid ${formatPeso(f.amount)} for "${f.bookTitle}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await FineService.instance.markPaid(f, staff: widget.user);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Marked as paid. ${f.studentName} has been notified.'),
        ),
      );
    } on FineChangedException {
      messenger.showSnackBar(
        const SnackBar(content: Text('This fine was already marked as paid.')),
      );
    } catch (e) {
      debugPrint('mark paid failed: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
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
            children: [FineDetailBody(fine: f, showStaffInfo: true)],
          ),
          bottomNavigationBar: f.isPaid
              ? null
              : Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: ElevatedButton(
                        onPressed: _busy ? null : () => _markPaid(f),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Mark as Paid'),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
