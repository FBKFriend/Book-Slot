import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  final String id; // BK-0001
  final String title;
  final String author;
  final String description;
  final List<String> genres;
  final int? publicationYear;
  final int totalCopies;
  final int availableCopies;
  final int reservedCopies; // copies held for accepted reservations
  final int coverVersion; // 0 = no cover; goes up each time the cover changes
  final DateTime? dateAdded;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.genres,
    required this.publicationYear,
    required this.totalCopies,
    required this.availableCopies,
    this.reservedCopies = 0,
    required this.coverVersion,
    required this.dateAdded,
  });

  bool get hasCover => coverVersion > 0;
  int get freeCopies => availableCopies - reservedCopies;

  factory Book.fromMap(String id, Map<String, dynamic> d) => Book(
    id: id,
    title: (d['title'] ?? '') as String,
    author: (d['author'] ?? '') as String,
    description: (d['description'] ?? '') as String,
    genres: List<String>.from((d['genres'] ?? const []) as List),
    publicationYear: (d['publicationYear'] as num?)?.toInt(),
    totalCopies: ((d['totalCopies'] ?? 0) as num).toInt(),
    availableCopies: ((d['availableCopies'] ?? 0) as num).toInt(),
    reservedCopies: ((d['reservedCopies'] ?? 0) as num).toInt(),
    coverVersion: ((d['coverVersion'] ?? 0) as num).toInt(),
    dateAdded: (d['dateAdded'] as Timestamp?)?.toDate(),
  );
}
