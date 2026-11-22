import 'book.dart';
import 'borrowing.dart';
import 'history_entry.dart';
import 'reservation.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// One bar group in the activity chart (a day or a month).
class TrendPoint {
  final String label;
  final int borrowed;
  final int returned;
  const TrendPoint({
    required this.label,
    required this.borrowed,
    required this.returned,
  });
}

/// One line in a ranking list.
class RankItem {
  final String label;
  final int count;
  final String? sub;
  const RankItem(this.label, this.count, [this.sub]);
}

List<RankItem> _top(
  Map<String, int> counts,
  String Function(String key) label, {
  String Function(String key)? sub,
  int n = 5,
}) {
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0
          ? byCount
          : label(a).toLowerCase().compareTo(label(b).toLowerCase());
    });
  return [
    for (final k in keys.take(n)) RankItem(label(k), counts[k]!, sub?.call(k)),
  ];
}

/// Everything the Reports tab shows for one period.
class ReportData {
  final int borrowed;
  final int returned;
  final int lateReturns;
  final int reservationsMade;
  final int pickedUp; // approved reservations that were collected
  final int expiredReservations; // approved but never collected
  final int activeReaders;
  final int titlesNotBorrowed;
  final int totalTitles;
  final double? avgDaysKept;
  final List<TrendPoint> trend;
  final List<RankItem> topBooks;
  final List<RankItem> topGenres;
  final List<RankItem> topReaders;
  final List<RankItem> byCourse;
  final List<RankItem> reservationOutcomes;

  const ReportData({
    required this.borrowed,
    required this.returned,
    required this.lateReturns,
    required this.reservationsMade,
    required this.pickedUp,
    required this.expiredReservations,
    required this.activeReaders,
    required this.titlesNotBorrowed,
    required this.totalTitles,
    required this.avgDaysKept,
    required this.trend,
    required this.topBooks,
    required this.topGenres,
    required this.topReaders,
    required this.byCourse,
    required this.reservationOutcomes,
  });

  /// Of the approved reservations that are finished, how many were collected.
  double? get pickupRate {
    final denom = pickedUp + expiredReservations;
    return denom == 0 ? null : pickedUp / denom;
  }

  double? get lateRate => returned == 0 ? null : lateReturns / returned;

  factory ReportData.compute({
    required List<HistoryEntry> events, // borrows and returns in the period
    required List<Reservation> reservations, // made in the period
    required List<Borrowing> borrowings, // started in the period
    required List<Book> books,
    required Map<String, String> courseByEmail,
    required DateTime? start,
    required DateTime? endExclusive,
    required DateTime now,
  }) {
    final borrows = events.where((e) => e.type == 'borrow').toList();
    final returns = events.where((e) => e.type == 'return').toList();
    final booksById = {for (final b in books) b.id: b};

    final bookCount = <String, int>{};
    final bookTitle = <String, String>{};
    final genreCount = <String, int>{};
    final readerCount = <String, int>{};
    final readerName = <String, String>{};
    final readerId = <String, String>{};
    final courseCount = <String, int>{};

    for (final e in borrows) {
      bookCount[e.bookId] = (bookCount[e.bookId] ?? 0) + 1;
      bookTitle[e.bookId] = e.bookTitle;

      for (final g in booksById[e.bookId]?.genres ?? const <String>[]) {
        genreCount[g] = (genreCount[g] ?? 0) + 1;
      }

      readerCount[e.studentEmail] = (readerCount[e.studentEmail] ?? 0) + 1;
      readerName[e.studentEmail] = e.studentName.isEmpty
          ? e.studentEmail
          : e.studentName;
      readerId[e.studentEmail] = e.studentId ?? '';

      final course = (courseByEmail[e.studentEmail] ?? '').trim().toUpperCase();
      final key = course.isEmpty ? 'Unknown' : course;
      courseCount[key] = (courseCount[key] ?? 0) + 1;
    }

    // Average days a book was kept, for borrows from this period that
    // have already come back
    var keptDays = 0.0;
    var keptCount = 0;
    for (final b in borrowings) {
      final from = b.borrowedAt;
      final to = b.returnedAt;
      if (b.status == 'returned' && from != null && to != null) {
        keptDays += to.difference(from).inMinutes / 1440;
        keptCount++;
      }
    }

    // How the reservations made in this period ended up
    final status = <String, int>{};
    for (final r in reservations) {
      status[r.status] = (status[r.status] ?? 0) + 1;
    }
    final pickedUp = (status['picked_up'] ?? 0) + (status['returned'] ?? 0);
    final expired = status['expired'] ?? 0;
    final outcomes = <RankItem>[
      RankItem('Borrowed', pickedUp),
      RankItem('Pending', status['pending'] ?? 0),
      RankItem('Approved (waiting)', status['accepted'] ?? 0),
      RankItem('Denied', status['denied'] ?? 0),
      RankItem('Expired', expired),
      RankItem('Dropped', status['dropped'] ?? 0),
      RankItem('Cancelled', status['cancelled'] ?? 0),
    ].where((i) => i.count > 0).toList();

    return ReportData(
      borrowed: borrows.length,
      returned: returns.length,
      lateReturns: returns.where((e) => e.overdue).length,
      reservationsMade: reservations.length,
      pickedUp: pickedUp,
      expiredReservations: expired,
      activeReaders: readerCount.length,
      titlesNotBorrowed: books
          .where((b) => !bookCount.containsKey(b.id))
          .length,
      totalTitles: books.length,
      avgDaysKept: keptCount == 0 ? null : keptDays / keptCount,
      trend: _trend(events, start, endExclusive, now),
      topBooks: _top(bookCount, (id) => bookTitle[id] ?? id, sub: (id) => id),
      topGenres: _top(genreCount, (g) => g),
      topReaders: _top(
        readerCount,
        (e) => readerName[e] ?? e,
        sub: (e) => readerId[e] ?? '',
      ),
      byCourse: _top(courseCount, (c) => c),
      reservationOutcomes: outcomes,
    );
  }

  /// Daily bars for short periods, monthly bars for long ones.
  static List<TrendPoint> _trend(
    List<HistoryEntry> events,
    DateTime? start,
    DateTime? endExclusive,
    DateTime now,
  ) {
    DateTime? first = start;
    if (first == null) {
      for (final e in events) {
        final at = e.createdAt;
        if (at != null && (first == null || at.isBefore(first))) first = at;
      }
    }
    if (first == null) return const [];

    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final end = (endExclusive == null || endExclusive.isAfter(tomorrow))
        ? tomorrow
        : endExclusive;
    final firstDay = DateTime(first.year, first.month, first.day);
    final monthly = end.difference(firstDay).inDays > 45;

    DateTime bucket(DateTime d) =>
        monthly ? DateTime(d.year, d.month) : DateTime(d.year, d.month, d.day);
    DateTime next(DateTime d) => monthly
        ? DateTime(d.year, d.month + 1)
        : DateTime(d.year, d.month, d.day + 1);

    var starts = <DateTime>[];
    for (var c = bucket(firstDay); c.isBefore(end); c = next(c)) {
      starts.add(c);
    }
    if (starts.length > 24 && monthly) {
      starts = starts.sublist(starts.length - 24); // last 2 years
    }

    final borrowed = <DateTime, int>{};
    final returned = <DateTime, int>{};
    for (final e in events) {
      final at = e.createdAt;
      if (at == null) continue;
      final k = bucket(at);
      if (e.type == 'borrow') {
        borrowed[k] = (borrowed[k] ?? 0) + 1;
      } else if (e.type == 'return') {
        returned[k] = (returned[k] ?? 0) + 1;
      }
    }

    final multiYear =
        starts.isNotEmpty && starts.first.year != starts.last.year;
    return [
      for (final s in starts)
        TrendPoint(
          label: monthly
              ? (multiYear
                    ? '${_monthNames[s.month - 1]} ${s.year % 100}'
                    : _monthNames[s.month - 1])
              : '${s.day}',
          borrowed: borrowed[s] ?? 0,
          returned: returned[s] ?? 0,
        ),
    ];
  }
}
