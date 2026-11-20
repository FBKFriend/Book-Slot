import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/book.dart';
import '../models/borrowing.dart';
import '../models/reservation.dart';
import 'qr_payload.dart';

/// What the librarian's scanner found out about a scanned code.
class ScanResult {
  final String? error; // set when the code can't be used
  final bool deadlinePassed;
  final QrKind? kind;
  final Reservation? reservation;
  final Borrowing? borrowing; // return scans only
  final Book? book;

  const ScanResult.problem(this.error, {this.deadlinePassed = false})
    : kind = null,
      reservation = null,
      borrowing = null,
      book = null;

  const ScanResult.forPickup(this.reservation, this.book)
    : error = null,
      deadlinePassed = false,
      kind = QrKind.pickup,
      borrowing = null;

  const ScanResult.forReturn(this.reservation, this.borrowing, this.book)
    : error = null,
      deadlinePassed = false,
      kind = QrKind.returning;
}

class QrScanService {
  QrScanService._();
  static final QrScanService instance = QrScanService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Book?> _book(String id) async {
    final snap = await _db.collection('books').doc(id).get();
    final d = snap.data();
    return d == null ? null : Book.fromMap(snap.id, d);
  }

  /// Checks the live records, so an old or reused QR gets a clear message
  /// instead of an error.
  Future<ScanResult> resolve(QrPayload p) async {
    final snap = await _db
        .collection('reservations')
        .doc(p.reservationId)
        .get();
    final data = snap.data();
    if (data == null) {
      return const ScanResult.problem(
        'This QR code is not valid. The reservation no longer exists.',
      );
    }
    final r = Reservation.fromDoc(snap.id, data);

    if (p.kind == QrKind.pickup) {
      switch (r.status) {
        case 'accepted':
          final deadline = r.pickupDeadline;
          if (deadline != null && deadline.isBefore(DateTime.now())) {
            return const ScanResult.problem(
              'The pickup deadline has passed, so this reservation is expiring.',
              deadlinePassed: true,
            );
          }
          return ScanResult.forPickup(r, await _book(r.bookId));
        case 'pending':
          return const ScanResult.problem(
            'This reservation has not been accepted yet.',
          );
        case 'picked_up':
          return const ScanResult.problem('This book was already picked up.');
        case 'returned':
          return const ScanResult.problem(
            'This reservation is already completed. The book was returned.',
          );
        default:
          return ScanResult.problem(
            'This reservation can no longer be used (status: ${r.status}).',
          );
      }
    }

    // Return QR
    if (r.status == 'returned') {
      return const ScanResult.problem('This book was already returned.');
    }
    if (r.status != 'picked_up') {
      return const ScanResult.problem(
        'This QR code is not for a borrowed book.',
      );
    }
    final found = await _db
        .collection('borrowings')
        .where('reservationId', isEqualTo: r.id)
        .get();
    final active = found.docs
        .where((d) => d.data()['status'] == 'active')
        .toList();
    if (active.isEmpty) {
      return const ScanResult.problem(
        'No active borrowing was found for this book.',
      );
    }
    return ScanResult.forReturn(
      r,
      Borrowing.fromDoc(active.first.id, active.first.data()),
      await _book(r.bookId),
    );
  }
}
