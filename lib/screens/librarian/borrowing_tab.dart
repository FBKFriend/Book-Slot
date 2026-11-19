import 'dart:async';

// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/book.dart';
import '../../models/reservation.dart';
import '../../services/book_service.dart';
import '../../services/reservation_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';

class BorrowingTab extends StatefulWidget {
  final AppUser user;
  final bool active; // true while this tab is the visible one
  const BorrowingTab({super.key, required this.user, required this.active});

  @override
  State<BorrowingTab> createState() => _BorrowingTabState();
}

class _BorrowingTabState extends State<BorrowingTab> {
  late final Stream<List<Reservation>> _stream = ReservationService.instance
      .watchOpen();
  StreamSubscription<List<Book>>? _booksSub;
  Map<String, Book> _books = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _booksSub = BookService.instance.watchBooks().listen((list) {
      if (mounted) setState(() => _books = {for (final b in list) b.id: b});
    }, onError: (_) {});
    _expireOverdue();
  }

  @override
  void didUpdateWidget(covariant BorrowingTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _expireOverdue();
  }

  @override
  void dispose() {
    _booksSub?.cancel();
    super.dispose();
  }

  Future<void> _expireOverdue() async {
    try {
      final n = await ReservationService.instance.expireOverdue(
        actorRole: widget.user.role,
      );
      if (n > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              n == 1
                  ? '1 reservation expired (pickup deadline passed)'
                  : '$n reservations expired (pickup deadline passed)',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('expire overdue failed: $e');
    }
  }

  Future<void> _run(
    Reservation r,
    Future<void> Function() action,
    String okMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(r.id));
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(okMessage)));
    } on NoFreeCopyException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No free copy: the last copy is already held by another accepted reservation.',
          ),
        ),
      );
    } on ReservationChangedException {
      messenger.showSnackBar(
        const SnackBar(content: Text('This request was already handled.')),
      );
    } on BookNotFoundException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'This book no longer exists. You can deny the request.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('reservation action failed: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
    if (mounted) setState(() => _busy.remove(r.id));
  }

  Future<void> _accept(Reservation r) => _run(
    r,
    () => ReservationService.instance.accept(r, actorRole: widget.user.role),
    'Accepted. ${r.studentName} has been notified.',
  );

  Future<void> _deny(Reservation r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deny reservation?'),
        content: Text(
          '${r.studentName} will be notified that the reservation for "${r.bookTitle}" was denied.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deny'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      r,
      () => ReservationService.instance.deny(r, actorRole: widget.user.role),
      'Denied. ${r.studentName} has been notified.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<List<Reservation>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <Reservation>[];
        final far = DateTime(9999);
        final pending = all.where((r) => r.status == 'pending').toList()
          ..sort((a, b) => (a.createdAt ?? far).compareTo(b.createdAt ?? far));
        final accepted = all.where((r) => r.status == 'accepted').toList()
          ..sort(
            (a, b) =>
                (a.pickupDeadline ?? far).compareTo(b.pickupDeadline ?? far),
          );

        Widget body;
        if (snap.hasError) {
          body = const Center(child: Text('Could not load reservations.'));
        } else if (!snap.hasData) {
          body = const Center(child: CircularProgressIndicator());
        } else {
          body = TabBarView(
            children: [
              pending.isEmpty
                  ? Center(
                      child: Text('No pending requests', style: t.bodySmall),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: pending.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final r = pending[i];
                        return _RequestCard(
                          r: r,
                          book: _books[r.bookId],
                          busy: _busy.contains(r.id),
                          onAccept: () => _accept(r),
                          onDeny: () => _deny(r),
                        );
                      },
                    ),
              accepted.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing waiting for pickup',
                        style: t.bodySmall,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: accepted.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) => _PickupCard(accepted[i]),
                    ),
            ],
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Borrowing & Reservations'),
              bottom: TabBar(
                dividerColor: AppColors.border,
                tabs: [
                  Tab(text: 'Requests (${pending.length})'),
                  Tab(text: 'To pick up (${accepted.length})'),
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

class _StudentLine extends StatelessWidget {
  final Reservation r;
  const _StudentLine(this.r);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = r.studentName.isEmpty ? r.studentEmail : r.studentName;
    final sub = [
      if ((r.studentId ?? '').isNotEmpty) r.studentId!,
      r.studentEmail,
    ].join('  ·  ');
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.background,
          child: Text(
            name.isEmpty ? '?' : name.characters.first.toUpperCase(),
            style: const TextStyle(color: AppColors.gold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Reservation r;
  final Book? book;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDeny;
  const _RequestCard({
    required this.r,
    required this.book,
    required this.busy,
    required this.onAccept,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final b = book;
    final free = b?.freeCopies;
    final noFree = free != null && free <= 0;
    final stockColor = noFree
        ? const Color(0xFFE57373)
        : const Color(0xFF7FB77E);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StudentLine(r),
            const Divider(color: AppColors.border, height: 24),
            Text(
              r.bookTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(
                color: AppColors.heading,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              r.createdAt == null
                  ? '${r.bookId}  ·  Just now'
                  : '${r.bookId}  ·  Requested ${formatDateTime(r.createdAt!)}',
              style: t.bodySmall,
            ),
            if (b != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: stockColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      noFree
                          ? 'No free copy: held for another student'
                          : '$free of ${b.totalCopies} ${b.totalCopies == 1 ? 'copy' : 'copies'} free',
                      style: TextStyle(color: stockColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: const Color(0xFFE57373),
                    ),
                    onPressed: busy ? null : onDeny,
                    child: const Text('Deny'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: (busy || noFree) ? null : onAccept,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickupCard extends StatelessWidget {
  final Reservation r;
  const _PickupCard(this.r);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = r.pickupDeadline;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StudentLine(r),
            const Divider(color: AppColors.border, height: 24),
            Text(
              r.bookTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(
                color: AppColors.heading,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(r.bookId, style: t.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  d == null
                      ? 'Waiting for pickup'
                      : 'Pick up by ${formatDate(d)}',
                  style: const TextStyle(color: AppColors.gold, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
