import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/book.dart';
import 'audit_service.dart';

class BookNotFoundException implements Exception {
  const BookNotFoundException();
}

class CopiesBelowBorrowedException implements Exception {
  final int borrowed;
  const CopiesBelowBorrowedException(this.borrowed);
}

class BookInUseException implements Exception {
  final int borrowed;
  const BookInUseException(this.borrowed);
}

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

  /// Live view of one book. Emits null if it was deleted.
  Stream<Book?> watchBook(String id) {
    return _db.collection('books').doc(id).snapshots().map((s) {
      final d = s.data();
      return d == null ? null : Book.fromMap(s.id, d);
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
        // ignore: use_null_aware_elements
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

  /// Updates a book. Reads the current stock inside the transaction, so a
  /// borrow happening at the same moment can't be overwritten.
  Future<void> updateBook({
    required String actorRole,
    required String id,
    required String title,
    required String author,
    required String description,
    required List<String> genres, // already sorted
    int? publicationYear,
    required int totalCopies,
    Uint8List? newCover,
    bool removeCover = false,
  }) {
    final bookRef = _db.collection('books').doc(id);
    final coverRef = _db.collection('bookCovers').doc(id);
    final logRef = AuditService.instance.newRef();
    final newTitle = title.trim();
    final newAuthor = author.trim();
    final newDescription = description.trim();

    return _db.runTransaction<void>((tx) async {
      final snap = await tx.get(bookRef);
      final old = snap.data();
      if (old == null) throw const BookNotFoundException();

      final oldTotal = ((old['totalCopies'] ?? 0) as num).toInt();
      final oldAvailable = ((old['availableCopies'] ?? 0) as num).toInt();
      final borrowed = oldTotal - oldAvailable;
      if (totalCopies < borrowed) throw CopiesBelowBorrowedException(borrowed);
      final reserved = ((old['reservedCopies'] ?? 0) as num).toInt();
      if (totalCopies < borrowed + reserved) {
        throw CopiesBelowBorrowedException(borrowed + reserved);
      }

      final oldVersion = ((old['coverVersion'] ?? 0) as num).toInt();
      var version = oldVersion;
      if (newCover != null) {
        // Unique version so every device fetches the new picture
        version = DateTime.now().millisecondsSinceEpoch;
        tx.set(coverRef, {
          'data': Blob(newCover),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (removeCover && oldVersion > 0) {
        version = 0;
        tx.delete(coverRef);
      }

      // What changed, for the audit log
      final changes = <String>[];
      if ((old['title'] ?? '') != newTitle) {
        changes.add('Title: ${old['title']} → $newTitle');
      }
      if ((old['author'] ?? '') != newAuthor) {
        changes.add('Author: ${old['author']} → $newAuthor');
      }
      if ((old['description'] ?? '') != newDescription) {
        changes.add('Description updated');
      }
      final oldGenres = List<String>.from((old['genres'] ?? const []) as List)
        ..sort();
      if (oldGenres.join('|') != genres.join('|')) {
        changes.add('Genres updated');
      }
      final oldYear = (old['publicationYear'] as num?)?.toInt();
      if (oldYear != publicationYear) {
        changes.add(
          'Publication year: ${oldYear ?? 'none'} → ${publicationYear ?? 'none'}',
        );
      }
      if (oldTotal != totalCopies) {
        changes.add('Total copies: $oldTotal → $totalCopies');
      }
      if (newCover != null) changes.add('Cover changed');
      if (newCover == null && removeCover && oldVersion > 0) {
        changes.add('Cover removed');
      }
      if (changes.isEmpty) return; // nothing to save

      tx.update(bookRef, {
        'title': newTitle,
        'author': newAuthor,
        'description': newDescription,
        'genres': genres,
        'publicationYear': publicationYear ?? FieldValue.delete(),
        'totalCopies': totalCopies,
        'availableCopies': totalCopies - borrowed,
        'coverVersion': version,
      });
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'book.edit',
          category: 'books',
          actorRole: actorRole,
          details: '$id - $newTitle\n${changes.join('\n')}',
        ),
      );
    });
  }

  /// Deletes a book and its cover. Only allowed when every copy is in stock.
  Future<void> deleteBook({required String actorRole, required String id}) {
    final bookRef = _db.collection('books').doc(id);
    final coverRef = _db.collection('bookCovers').doc(id);
    final logRef = AuditService.instance.newRef();

    return _db.runTransaction<void>((tx) async {
      final snap = await tx.get(bookRef);
      final d = snap.data();
      if (d == null) throw const BookNotFoundException();

      final total = ((d['totalCopies'] ?? 0) as num).toInt();
      final available = ((d['availableCopies'] ?? 0) as num).toInt();
      if (available != total) throw BookInUseException(total - available);
      final reserved = ((d['reservedCopies'] ?? 0) as num).toInt();
      if (reserved > 0) throw BookInUseException(reserved);

      tx.delete(bookRef);
      tx.delete(coverRef);
      tx.set(
        logRef,
        AuditService.instance.entryData(
          action: 'book.delete',
          category: 'books',
          actorRole: actorRole,
          details: '$id - ${d['title'] ?? ''}',
        ),
      );
    });
  }
}
