import 'package:flutter/material.dart';

import '../../services/fine_service.dart';
import '../../models/app_user.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import '../../utils/format.dart';
import '../../models/book.dart';
import '../../services/book_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/genre_tags.dart';

void openBookDetail(BuildContext context, Book book, AppUser user) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BookDetailScreen(book: book, user: user),
    ),
  );
}

class BookDetailScreen extends StatefulWidget {
  final Book book;
  final AppUser user;
  const BookDetailScreen({super.key, required this.book, required this.user});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late final Stream<Book?> _stream = BookService.instance.watchBook(
    widget.book.id,
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<Book?>(
      stream: _stream,
      initialData: widget.book,
      builder: (context, snap) {
        final appBar = AppBar(title: const Text('Book details'));
        if (snap.hasError) {
          return Scaffold(
            appBar: appBar,
            body: const Center(child: Text('Could not load this book.')),
          );
        }
        final b = snap.data;
        if (b == null) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Text(
                'This book is no longer in the library.',
                style: t.bodySmall,
              ),
            ),
          );
        }

        final out = b.availableCopies == 0;
        final stockColor = out
            ? const Color(0xFFE57373)
            : const Color(0xFF7FB77E);
        final genres = [...b.genres]..sort();

        return Scaffold(
          appBar: appBar,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: BookCover(
                  bookId: b.id,
                  version: b.coverVersion,
                  width: 160,
                  height: 240,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                b.title,
                textAlign: TextAlign.center,
                style: t.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(b.author, textAlign: TextAlign.center, style: t.bodyLarge),
              const SizedBox(height: 4),
              Text(
                b.publicationYear == null
                    ? b.id
                    : '${b.id}  ·  ${b.publicationYear}',
                textAlign: TextAlign.center,
                style: t.bodySmall,
              ),
              if (genres.isNotEmpty) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.center,
                  child: GenreTags(genres: genres, maxShown: genres.length),
                ),
              ],
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: stockColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          out
                              ? 'No copies available right now'
                              : '${b.availableCopies} of ${b.totalCopies} ${b.totalCopies == 1 ? 'copy' : 'copies'} available',
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('About this book', style: t.titleLarge),
              const SizedBox(height: 8),
              Text(
                b.description.isEmpty
                    ? 'No description provided.'
                    : b.description,
                style: b.description.isEmpty
                    ? t.bodySmall
                    : t.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
          bottomNavigationBar: _ReserveBar(book: b, user: widget.user),
        );
      },
    );
  }
}

class _ReserveBar extends StatefulWidget {
  final Book book;
  final AppUser user;
  const _ReserveBar({required this.book, required this.user});

  @override
  State<_ReserveBar> createState() => _ReserveBarState();
}

class _ReserveBarState extends State<_ReserveBar> {
  late final Stream<List<Reservation>> _stream = ReservationService.instance
      .watchForStudent(widget.user.email);
  bool _busy = false;

  Future<void> _reserve() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ReservationService.instance.reserve(
        book: widget.book,
        user: widget.user,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Reservation sent. You will get an alert when the librarian responds.',
          ),
        ),
      );
    } on AlreadyReservedException {
      messenger.showSnackBar(
        const SnackBar(content: Text('You already reserved this book.')),
      );
    } on ReservationLimitException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'You can only have ${e.limit} active reservations at a time.',
          ),
        ),
      );
    } on UnpaidFineException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'You have an unpaid fine. Please settle it at the library before reserving books.',
          ),
        ),
      );
    } on BookUnavailableException {
      messenger.showSnackBar(
        const SnackBar(content: Text('This book has no copies available.')),
      );
    } catch (e) {
      debugPrint('reserve failed: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not send the reservation. Please try again.'),
        ),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: StreamBuilder<List<Reservation>>(
            stream: _stream,
            builder: (context, snap) {
              final mine = (snap.data ?? const <Reservation>[])
                  .where(
                    (r) =>
                        r.bookId == widget.book.id &&
                        (r.isActive || r.isBorrowing),
                  )
                  .toList();
              final active = mine.isEmpty ? null : mine.first;

              var label = 'Reserve';
              String? note;
              var enabled = snap.hasData;

              if (snap.hasError) {
                enabled = false;
                note = 'Could not check your reservations.';
              } else if (active != null && active.isBorrowing) {
                enabled = false;
                label = 'Borrowed';
                note = active.dueAt == null
                    ? 'You are currently borrowing this book.'
                    : 'You are borrowing this book. Due ${formatDate(active.dueAt!)}.';
              } else if (active != null && active.status == 'accepted') {
                enabled = false;
                label = 'Reserved';
                note = active.pickupDeadline == null
                    ? 'Approved. Please pick it up at the library.'
                    : 'Approved. Pick it up by ${formatDate(active.pickupDeadline!)}.';
              } else if (active != null) {
                enabled = false;
                label = 'Reservation pending';
                note = 'Waiting for the librarian to respond.';
              } else if (widget.book.availableCopies == 0) {
                enabled = false;
                label = 'Unavailable';
                note = 'All copies are currently borrowed.';
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: (enabled && !_busy) ? _reserve : null,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(label),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 6),
                    Text(note, textAlign: TextAlign.center, style: t.bodySmall),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
