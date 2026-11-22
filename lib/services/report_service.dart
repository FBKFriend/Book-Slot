import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/book.dart';
import '../models/borrowing.dart';
import '../models/history_entry.dart';
import '../models/report_data.dart';
import '../models/reservation.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<QuerySnapshot<Map<String, dynamic>>> _ranged(
    String collection,
    String field,
    DateTime? start,
    DateTime? endExclusive,
  ) {
    Query<Map<String, dynamic>> q = _db.collection(collection);
    if (start != null) {
      q = q.where(field, isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    if (endExclusive != null) {
      q = q.where(field, isLessThan: Timestamp.fromDate(endExclusive));
    }
    return q.limit(10000).get();
  }

  /// One-time snapshot of the numbers for a period (null = no limit).
  Future<ReportData> build({DateTime? start, DateTime? endExclusive}) async {
    final results = await Future.wait([
      _ranged('transactions', 'createdAt', start, endExclusive),
      _ranged('reservations', 'createdAt', start, endExclusive),
      _ranged('borrowings', 'borrowedAt', start, endExclusive),
      _db.collection('books').get(),
      _db.collection('users').where('role', isEqualTo: 'student').get(),
    ]);

    final events = results[0].docs
        .map((d) => HistoryEntry.fromDoc(d.id, d.data()))
        .toList();
    final reservations = results[1].docs
        .map((d) => Reservation.fromDoc(d.id, d.data()))
        .toList();
    final borrowings = results[2].docs
        .map((d) => Borrowing.fromDoc(d.id, d.data()))
        .toList();
    final books = results[3].docs
        .map((d) => Book.fromMap(d.id, d.data()))
        .toList();
    final courseByEmail = {
      for (final d in results[4].docs)
        d.id: ((d.data()['course'] ?? '') as String),
    };

    return ReportData.compute(
      events: events,
      reservations: reservations,
      borrowings: borrowings,
      books: books,
      courseByEmail: courseByEmail,
      start: start,
      endExclusive: endExclusive,
      now: DateTime.now(),
    );
  }
}
