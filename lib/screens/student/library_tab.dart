import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/reservation.dart';
import '../../services/qr_payload.dart';
import '../../services/reservation_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/qr_sheet.dart';

class LibraryTab extends StatefulWidget {
  final AppUser user;
  const LibraryTab({super.key, required this.user});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  late final Stream<List<Reservation>> _stream = ReservationService.instance
      .watchForStudent(widget.user.email);
  final Set<String> _busy = {};

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancel(Reservation r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: Text(
          'Your reservation for "${r.bookTitle}" will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel reservation'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy.add(r.id));
    try {
      await ReservationService.instance.cancel(r);
      _snack('Reservation cancelled.');
    } on ReservationChangedException {
      _snack('The librarian already responded to this reservation.');
    } catch (e) {
      debugPrint('cancel failed: $e');
      _snack('Could not cancel. Please try again.');
    }
    if (mounted) setState(() => _busy.remove(r.id));
  }

  void _showPickupQr(Reservation r) {
    final d = r.pickupDeadline;
    showQrSheet(
      context,
      title: r.bookTitle,
      subtitle: 'Pickup QR code',
      data: QrPayload.pickup(r.id),
      hint: d == null
          ? 'Show this QR code to the librarian when you pick up the book.'
          : 'Show this QR code to the librarian when you pick up the book. Valid until ${formatDate(d)}.',
    );
  }

  void _showReturnQr(Reservation r) {
    showQrSheet(
      context,
      title: r.bookTitle,
      subtitle: 'Return QR code',
      data: QrPayload.returning(r.id),
      hint: 'Show this QR code and the book to the librarian to return it.',
    );
  }

  Widget _list<T>(
    List<T> items,
    String empty,
    Widget Function(T item) builder,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            empty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) => builder(items[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reservation>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <Reservation>[];
        final far = DateTime(9999);

        // Approved first (they need action), then pending, oldest first
        final current = all.where((r) => r.isActive).toList()
          ..sort((a, b) {
            final byStatus = (a.status == 'accepted' ? 0 : 1).compareTo(
              b.status == 'accepted' ? 0 : 1,
            );
            return byStatus != 0
                ? byStatus
                : (a.createdAt ?? far).compareTo(b.createdAt ?? far);
          });
        final borrowed = all.where((r) => r.isBorrowing).toList()
          ..sort((a, b) => (a.dueAt ?? far).compareTo(b.dueAt ?? far));

        Widget body;
        if (snap.hasError) {
          body = const Center(child: Text('Could not load your library.'));
        } else if (!snap.hasData) {
          body = const Center(child: CircularProgressIndicator());
        } else {
          body = TabBarView(
            children: [
              _list<Reservation>(
                current,
                'No active reservations. Reserve a book from the Catalog.',
                (r) => _ReservationCard(
                  r: r,
                  busy: _busy.contains(r.id),
                  onCancel: () => _cancel(r),
                  onShowQr: () => _showPickupQr(r),
                ),
              ),
              _list<Reservation>(
                borrowed,
                'You have no borrowed books.',
                (r) => _BorrowedCard(r: r, onShowQr: () => _showReturnQr(r)),
              ),
            ],
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('My Library'),
              bottom: TabBar(
                dividerColor: AppColors.border,
                tabs: [
                  Tab(text: 'Reservations (${current.length})'),
                  Tab(text: 'Borrowed (${borrowed.length})'),
                ],
              ),
            ),
            body: body,
          ),
        );
      },
    );
  }
}

class _BookHeader extends StatelessWidget {
  final Reservation r;
  const _BookHeader(this.r);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.background,
          child: Icon(
            Icons.menu_book_outlined,
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
                r.bookTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.titleMedium?.copyWith(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(r.bookId, style: t.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Reservation r;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onShowQr;
  const _ReservationCard({
    required this.r,
    required this.busy,
    required this.onCancel,
    required this.onShowQr,
  });

  @override
  Widget build(BuildContext context) {
    final accepted = r.status == 'accepted';
    final d = r.pickupDeadline;
    final color = accepted ? const Color(0xFF7FB77E) : AppColors.gold;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookHeader(r),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  accepted ? Icons.check_circle_outline : Icons.hourglass_top,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    accepted
                        ? (d == null
                              ? 'Approved. Pick it up at the library.'
                              : 'Approved. Pick up by ${formatDate(d)}.')
                        : (r.createdAt == null
                              ? 'Waiting for the librarian'
                              : 'Waiting for the librarian · requested ${formatDate(r.createdAt!)}'),
                    style: TextStyle(color: color, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (accepted)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: onShowQr,
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Show pickup QR'),
              )
            else
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: const Color(0xFFE57373),
                ),
                onPressed: busy ? null : onCancel,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cancel reservation'),
              ),
          ],
        ),
      ),
    );
  }
}

class _BorrowedCard extends StatelessWidget {
  final Reservation r;
  final VoidCallback onShowQr;
  const _BorrowedCard({required this.r, required this.onShowQr});

  @override
  Widget build(BuildContext context) {
    final due = r.dueAt;
    final overdue = due != null && due.isBefore(DateTime.now());
    final color = overdue ? const Color(0xFFE57373) : AppColors.gold;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookHeader(r),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  due == null
                      ? 'Currently borrowed'
                      : overdue
                      ? 'Overdue · was due ${formatDate(due)}'
                      : 'Due ${formatDate(due)}',
                  style: TextStyle(color: color, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: onShowQr,
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Show return QR'),
            ),
          ],
        ),
      ),
    );
  }
}
