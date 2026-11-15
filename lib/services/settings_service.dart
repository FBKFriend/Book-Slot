import 'package:cloud_firestore/cloud_firestore.dart';

import 'audit_service.dart';
import '../models/system_settings.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  final DocumentReference<Map<String, dynamic>> _doc = FirebaseFirestore
      .instance
      .collection('settings')
      .doc('system');

  /// Live settings. If the document doesn't exist yet, you get the defaults.
  Stream<SystemSettings> watch() =>
      _doc.snapshots().map((s) => SystemSettings.fromMap(s.data()));

  Future<void> save(SystemSettings s) {
    final logRef = AuditService.instance.newRef();
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final old = SystemSettings.fromMap((await tx.get(_doc)).data());
      tx.set(_doc, {...s.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
      final changes = <String>[
        if (old.borrowDays != s.borrowDays)
          'Borrowing duration: ${old.borrowDays} → ${s.borrowDays} days',
        if (old.maxBorrowedBooks != s.maxBorrowedBooks)
          'Max books at once: ${old.maxBorrowedBooks} → ${s.maxBorrowedBooks}',
        if (old.pickupDeadlineDays != s.pickupDeadlineDays)
          'Pickup deadline: ${old.pickupDeadlineDays} → ${s.pickupDeadlineDays} days',
        if (old.maxActiveReservations != s.maxActiveReservations)
          'Max active reservations: ${old.maxActiveReservations} → ${s.maxActiveReservations}',
      ];
      if (changes.isNotEmpty) {
        tx.set(
          logRef,
          AuditService.instance.entryData(
            action: 'settings.update',
            category: 'settings',
            details: changes.join('\n'),
          ),
        );
      }
    });
  }
}
