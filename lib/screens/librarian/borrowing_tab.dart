import 'dart:async';

// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/fine.dart';
import '../../services/fine_service.dart';
import 'fines_list.dart';
import '../../models/app_user.dart';
import '../../models/book.dart';
import '../../models/borrowing.dart';
import '../../models/reservation.dart';
import '../../services/book_service.dart';
import '../../services/borrowing_service.dart';
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
  late final Stream<List<Borrowing>> _borrowedStream = BorrowingService.instance
      .watchActive();
  StreamSubscription<List<Book>>? _booksSub;
  StreamSubscription<List<Fine>>? _finesSub;
  List<Fine> _fines = const [];
  Map<String, Book> _books = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _booksSub = BookService.instance.watchBooks().listen((list) {
      if (mounted) setState(() => _books = {for (final b in list) b.id: b});
    }, onError: (_) {});
    _expireOverdue();
    _finesSub = FineService.instance.watchAll().listen((list) {
      if (mounted) setState(() => _fines = list);
    }, onError: (_) {});
  }

  @override
  void didUpdateWidget(covariant BorrowingTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _expireOverdue();
  }

  @override
  void dispose() {
    _booksSub?.cancel();
    _finesSub?.cancel();
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

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs one librarian action, with a busy spinner and friendly errors.
  Future<void> _run(
    String id,
    Future<void> Function() action,
    String okMessage,
  ) async {
    setState(() => _busy.add(id));
    try {
      await action();
      if (mounted) _snack(okMessage);
    } on NoFreeCopyException {
      if (mounted) {
        _snack(
          'No free copy: the last copy is already held by another accepted reservation.',
        );
      }
    } on ReservationChangedException {
      if (mounted) _snack('This request was already handled.');
    } on BookNotFoundException {
      if (mounted) {
        _snack('This book no longer exists. You can deny the request.');
      }
    } on BorrowLimitException catch (e) {
      if (mounted) {
        _snack(
          'This student already has ${e.limit} books borrowed, which is the limit.',
        );
      }
    } on PickupExpiredException {
      try {
        await ReservationService.instance.expireOverdue(
          actorRole: widget.user.role,
        );
      } catch (_) {}
      if (mounted) {
        _snack('The pickup deadline has passed, so this reservation expired.');
      }
    } on BorrowingChangedException {
      if (mounted) _snack('This book was already returned.');
    } on UnpaidFineException {
      if (mounted) {
        _snack(
          'This student has an unpaid fine. Deny the request or ask them to settle it first.',
        );
      }
    } catch (e) {
      debugPrint('action failed: $e');
      if (mounted) _snack('Something went wrong. Please try again.');
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _accept(Reservation r) => _run(
    r.id,
    () => ReservationService.instance.accept(r, actorRole: widget.user.role),
    'Accepted. ${r.studentName} has been notified.',
  );

  Future<void> _deny(Reservation r) async {
    final ok = await _confirm(
      'Deny reservation?',
      '${r.studentName} will be notified that the reservation for "${r.bookTitle}" was denied.',
      'Deny',
    );
    if (!ok) return;
    await _run(
      r.id,
      () => ReservationService.instance.deny(r, actorRole: widget.user.role),
      'Denied. ${r.studentName} has been notified.',
    );
  }

  Widget _list<T>(
    List<T> items,
    String empty,
    Widget Function(T item) builder,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Text(empty, style: Theme.of(context).textTheme.bodySmall),
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
      builder: (context, resSnap) {
        return StreamBuilder<List<Borrowing>>(
          stream: _borrowedStream,
          builder: (context, borSnap) {
            final all = resSnap.data ?? const <Reservation>[];
            final borrowed = borSnap.data ?? const <Borrowing>[];
            final far = DateTime(9999);
            final pending = all.where((r) => r.status == 'pending').toList()
              ..sort(
                (a, b) => (a.createdAt ?? far).compareTo(b.createdAt ?? far),
              );
            final accepted = all.where((r) => r.status == 'accepted').toList()
              ..sort(
                (a, b) => (a.pickupDeadline ?? far).compareTo(
                  b.pickupDeadline ?? far,
                ),
              );
            final unpaidFines = _fines.where((f) => !f.isPaid).length;

            Widget body;
            if (resSnap.hasError || borSnap.hasError) {
              body = const Center(child: Text('Could not load this tab.'));
            } else if (!resSnap.hasData || !borSnap.hasData) {
              body = const Center(child: CircularProgressIndicator());
            } else {
              body = TabBarView(
                children: [
                  _list<Reservation>(
                    pending,
                    'No pending requests',
                    (r) => _RequestCard(
                      r: r,
                      book: _books[r.bookId],
                      busy: _busy.contains(r.id),
                      onAccept: () => _accept(r),
                      onDeny: () => _deny(r),
                    ),
                  ),
                  _list<Reservation>(
                    accepted,
                    'Nothing waiting for pickup',
                    (r) => _PickupCard(r),
                  ),
                  _list<Borrowing>(
                    borrowed,
                    'No books are borrowed right now',
                    (b) => _BorrowedCard(b),
                  ),
                  FinesList(fines: _fines, user: widget.user),
                ],
              );
            }

            return DefaultTabController(
              length: 4,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Borrowing & Reservations'),
                  bottom: TabBar(
                    dividerColor: AppColors.border,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: 'Requests (${pending.length})'),
                      Tab(text: 'Pickup (${accepted.length})'),
                      Tab(text: 'Borrowed (${borrowed.length})'),
                      Tab(text: 'Fines ($unpaidFines)'),
                    ],
                  ),
                ),
                body: body,
              ),
            );
          },
        );
      },
    );
  }
}

class _StudentLine extends StatelessWidget {
  final String name;
  final String? studentId;
  final String email;
  const _StudentLine({
    required this.name,
    required this.studentId,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final title = name.isEmpty ? email : name;
    final sub = [
      if ((studentId ?? '').isNotEmpty) studentId!,
      email,
    ].join('  ·  ');
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.background,
          child: Text(
            title.isEmpty ? '?' : title.characters.first.toUpperCase(),
            style: const TextStyle(color: AppColors.gold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
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

Widget _spinner() => const SizedBox(
  width: 18,
  height: 18,
  child: CircularProgressIndicator(strokeWidth: 2),
);

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
            _StudentLine(
              name: r.studentName,
              studentId: r.studentId,
              email: r.studentEmail,
            ),
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
                    child: busy ? _spinner() : const Text('Accept'),
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
            _StudentLine(
              name: r.studentName,
              studentId: r.studentId,
              email: r.studentEmail,
            ),
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
            const SizedBox(height: 12),
            Text(
              "Scan the student's QR code in the Scan tab to hand over the book.",
              style: t.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BorrowedCard extends StatelessWidget {
  final Borrowing b;
  const _BorrowedCard(this.b);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final overdue = b.isOverdue;
    final color = overdue ? const Color(0xFFE57373) : AppColors.gold;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StudentLine(
              name: b.studentName,
              studentId: b.studentId,
              email: b.studentEmail,
            ),
            const Divider(color: AppColors.border, height: 24),
            Text(
              b.bookTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(
                color: AppColors.heading,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              b.borrowedAt == null
                  ? '${b.bookId}  ·  Borrowed just now'
                  : '${b.bookId}  ·  Borrowed ${formatDate(b.borrowedAt!)}',
              style: t.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  b.dueAt == null
                      ? 'No due date'
                      : overdue
                      ? 'Overdue · was due ${formatDate(b.dueAt!)}'
                      : 'Due ${formatDate(b.dueAt!)}',
                  style: TextStyle(color: color, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Scan the student's return QR code in the Scan tab to return it.",
              style: t.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
