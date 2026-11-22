import 'dart:async';

import '../models/book.dart';
import '../models/borrowing.dart';
import '../models/dashboard_stats.dart';
import '../models/history_entry.dart';
import '../models/reservation.dart';
import 'book_service.dart';
import 'borrowing_service.dart';
import 'reservation_service.dart';

class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  /// Live dashboard numbers. Emits once all four sources have loaded, then
  /// again whenever any of them changes (and once a minute, so "overdue"
  /// stays correct as due dates pass).
  Stream<DashboardStats> watch() {
    late final StreamController<DashboardStats> controller;
    final subs = <StreamSubscription<dynamic>>[];
    Timer? timer;

    List<Book>? books;
    List<Borrowing>? borrowings;
    List<Reservation>? open;
    List<HistoryEntry>? events;

    void emit() {
      final b = books, br = borrowings, o = open, e = events;
      if (b == null || br == null || o == null || e == null) return;
      controller.add(
        DashboardStats.compute(
          books: b,
          borrowings: br,
          open: o,
          events: e,
          now: DateTime.now(),
        ),
      );
    }

    controller = StreamController<DashboardStats>(
      onListen: () {
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final nextMonth = DateTime(now.year, now.month + 1, 1);

        subs.add(
          BookService.instance.watchBooks().listen((v) {
            books = v;
            emit();
          }, onError: controller.addError),
        );
        subs.add(
          BorrowingService.instance.watchActive().listen((v) {
            borrowings = v;
            emit();
          }, onError: controller.addError),
        );
        subs.add(
          ReservationService.instance.watchOpen().listen((v) {
            open = v;
            emit();
          }, onError: controller.addError),
        );
        subs.add(
          BorrowingService.instance
              .watchHistory(
                start: monthStart,
                endExclusive: nextMonth,
                limit: 5000,
              )
              .listen((v) {
                events = v;
                emit();
              }, onError: controller.addError),
        );
        timer = Timer.periodic(const Duration(minutes: 1), (_) => emit());
      },
      onCancel: () async {
        timer?.cancel();
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }
}
