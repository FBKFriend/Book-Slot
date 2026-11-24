import 'package:flutter/foundation.dart';

/// Days a book is late. It is due at the end of the due day, and any part
/// of a day counts as a full day.
int daysLateOf(DateTime due, [DateTime? now]) {
  final over = (now ?? DateTime.now()).difference(due);
  if (over.isNegative) return 0;
  final days = (over.inMinutes / 1440).ceil();
  return days < 1 ? 1 : days;
}

/// What the librarian reported while returning a book.
class ReturnIncident {
  final int? fineAmount; // whole pesos, null = no fine
  final bool damaged;
  final String damageReason;
  final String? condition; // functional | discarded
  final Uint8List? photo;

  const ReturnIncident({
    required this.fineAmount,
    required this.damaged,
    required this.damageReason,
    required this.condition,
    required this.photo,
  });

  bool get hasFine => fineAmount != null && fineAmount! > 0;
  bool get discarded => damaged && condition == 'discarded';
}

/// What the return/pickup confirm sheet gives back.
class ReturnDecision {
  final ReturnIncident? incident;
  const ReturnDecision([this.incident]);
}
