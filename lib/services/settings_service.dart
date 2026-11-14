import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> save(SystemSettings s) =>
      _doc.set({...s.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
}
