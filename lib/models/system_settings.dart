class SystemSettings {
  final int borrowDays;
  final int maxBorrowedBooks;
  final int pickupDeadlineDays;
  final int maxActiveReservations;

  const SystemSettings({
    required this.borrowDays,
    required this.maxBorrowedBooks,
    required this.pickupDeadlineDays,
    required this.maxActiveReservations,
  });

  static const defaults = SystemSettings(
    borrowDays: 7,
    maxBorrowedBooks: 3,
    pickupDeadlineDays: 2,
    maxActiveReservations: 3,
  );

  /// Missing fields (or a missing document) fall back to the defaults.
  factory SystemSettings.fromMap(Map<String, dynamic>? d) {
    int pick(String key, int fallback) =>
        (d?[key] as num?)?.toInt() ?? fallback;
    return SystemSettings(
      borrowDays: pick('borrowDays', defaults.borrowDays),
      maxBorrowedBooks: pick('maxBorrowedBooks', defaults.maxBorrowedBooks),
      pickupDeadlineDays: pick(
        'pickupDeadlineDays',
        defaults.pickupDeadlineDays,
      ),
      maxActiveReservations: pick(
        'maxActiveReservations',
        defaults.maxActiveReservations,
      ),
    );
  }

  Map<String, Object?> toMap() => {
    'borrowDays': borrowDays,
    'maxBorrowedBooks': maxBorrowedBooks,
    'pickupDeadlineDays': pickupDeadlineDays,
    'maxActiveReservations': maxActiveReservations,
  };

  SystemSettings copyWith({
    int? borrowDays,
    int? maxBorrowedBooks,
    int? pickupDeadlineDays,
    int? maxActiveReservations,
  }) => SystemSettings(
    borrowDays: borrowDays ?? this.borrowDays,
    maxBorrowedBooks: maxBorrowedBooks ?? this.maxBorrowedBooks,
    pickupDeadlineDays: pickupDeadlineDays ?? this.pickupDeadlineDays,
    maxActiveReservations: maxActiveReservations ?? this.maxActiveReservations,
  );

  bool sameAs(SystemSettings o) =>
      borrowDays == o.borrowDays &&
      maxBorrowedBooks == o.maxBorrowedBooks &&
      pickupDeadlineDays == o.pickupDeadlineDays &&
      maxActiveReservations == o.maxActiveReservations;
}
