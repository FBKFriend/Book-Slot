import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class CoverService {
  CoverService._();
  static final CoverService instance = CoverService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Remembers covers for this app session; the key includes the version,
  // so a changed cover is fetched again automatically.
  final Map<String, Future<Uint8List?>> _cache = {};

  Future<Uint8List?> load(String bookId, int version) {
    if (version <= 0) return Future.value(null);
    final key = '$bookId#$version';
    return _cache.putIfAbsent(key, () async {
      try {
        final snap = await _db.collection('bookCovers').doc(bookId).get();
        final data = snap.data()?['data'];
        return data is Blob ? data.bytes : null;
      } catch (_) {
        _cache.remove(key);
        return null;
      }
    });
  }
}
