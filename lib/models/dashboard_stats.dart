import 'book.dart';
import 'borrowing.dart';
import 'history_entry.dart';
import 'reservation.dart';

/// All the numbers the dashboards need, in one place.
class DashboardStats {
  final int titles; // different books in the catalog
  final int totalCopies;
  final int availableCopies; // on the shelf (not borrowed)
  final int heldCopies; // on the shelf, but held for approved reservations
  final int borrowedNow;
  final int overdue;
  final int pendingRequests;
  final int awaitingPickup;
  final int borrowedToday;
  final int returnedToday;
  final int borrowedThisMonth;

  const DashboardStats({
    required this.titles,
    required this.totalCopies,
    required this.availableCopies,
    required this.heldCopies,
    required this.borrowedNow,
    required this.overdue,
    required this.pendingRequests,
    required this.awaitingPickup,
    required this.borrowedToday,
    required this.returnedToday,
    required this.borrowedThisMonth,
  });

  factory DashboardStats.compute({
    required List<Book> books,
    required List<Borrowing> borrowings, // active ones
    required List<Reservation> open, // pending + accepted
    required List<HistoryEntry> events, // this month's borrows and returns
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);

    var totalCopies = 0, availableCopies = 0, heldCopies = 0;
    for (final b in books) {
      totalCopies += b.totalCopies;
      availableCopies += b.availableCopies;
      heldCopies += b.reservedCopies;
    }

    final overdue = borrowings
        .where((b) => b.dueAt != null && b.dueAt!.isBefore(now))
        .length;

    var borrowedToday = 0, returnedToday = 0, borrowedThisMonth = 0;
    for (final e in events) {
      final at = e.createdAt ?? now; // no date yet = just happened
      if (e.type == 'borrow') {
        borrowedThisMonth++;
        if (!at.isBefore(today)) borrowedToday++;
      } else if (e.type == 'return' && !at.isBefore(today)) {
        returnedToday++;
      }
    }

    return DashboardStats(
      titles: books.length,
      totalCopies: totalCopies,
      availableCopies: availableCopies,
      heldCopies: heldCopies,
      borrowedNow: borrowings.length,
      overdue: overdue,
      pendingRequests: open.where((r) => r.status == 'pending').length,
      awaitingPickup: open.where((r) => r.status == 'accepted').length,
      borrowedToday: borrowedToday,
      returnedToday: returnedToday,
      borrowedThisMonth: borrowedThisMonth,
    );
  }
}
