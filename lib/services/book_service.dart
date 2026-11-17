import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/book.dart';
import 'audit_service.dart';

class BookService {
  BookService._();
  static final BookService instance = BookService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Live list of all books, sorted by title.
  Stream<List<Book>> watchBooks() {
    return _db.collection('books').snapshots().map((snap) {
      final list = snap.docs.map((d) => Book.fromMap(d.id, d.data())).toList();
      list.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      return list;
    });
  }

  /// Creates the next book (BK-0001, BK-0002, ...) and returns its ID.
  Future<String> addBook({
    required String actorRole,
    required String title,
    required String author,
    required String description,
    required List<String> genres,
    int? publicationYear,
    required int totalCopies,
    Uint8List? cover,
  }) {
    final counterRef = _db.collection('counters').doc('books');
    final logRef = AuditService.instance.newRef();

    return _db.runTransaction<String>((tx) async {
      final snap = await tx.get(counterRef);
      final next = ((snap.data()?['next'] ?? 1) as num).toInt();
      final id = 'BK-${next.toString().padLeft(4, '0')}';
      final bookRef = _db.collection('books').doc(id);

      tx.set(counterRef, {'next': next + 1});
      tx.set(bookRef, {
        'title': title.trim(),
        'author': author.trim(),
        'description': description.trim(),
        'genres': genres,
        if (publicationYear != null) 'publicationYear': publicationYear,
        'totalCopies': totalCopies,
        'availableCopies': totalCopies,
        'coverVersion': cover == null ? 0 : 1,
        'dateAdded': FieldValue.serverTimestamp(),
      });
      if (cover != null) {
        tx.set(_db.collection('bookCovers').doc(id), {
          'data': Blob(cover),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'book.add',
          category: 'books',
          actorRole: actorRole,
          details: '$id - ${title.trim()}',
        ),
      );
      return id;
    });
  }
}
