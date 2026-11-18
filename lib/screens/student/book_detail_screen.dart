import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../services/book_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/genre_tags.dart';

void openBookDetail(BuildContext context, Book book) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
}

class BookDetailScreen extends StatefulWidget {
  final Book book;
  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late final Stream<Book?> _stream = BookService.instance.watchBook(
    widget.book.id,
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<Book?>(
      stream: _stream,
      initialData: widget.book,
      builder: (context, snap) {
        final appBar = AppBar(title: const Text('Book details'));
        if (snap.hasError) {
          return Scaffold(
            appBar: appBar,
            body: const Center(child: Text('Could not load this book.')),
          );
        }
        final b = snap.data;
        if (b == null) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Text(
                'This book is no longer in the library.',
                style: t.bodySmall,
              ),
            ),
          );
        }

        final out = b.availableCopies == 0;
        final stockColor = out
            ? const Color(0xFFE57373)
            : const Color(0xFF7FB77E);
        final genres = [...b.genres]..sort();

        return Scaffold(
          appBar: appBar,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: BookCover(
                  bookId: b.id,
                  version: b.coverVersion,
                  width: 160,
                  height: 240,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                b.title,
                textAlign: TextAlign.center,
                style: t.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(b.author, textAlign: TextAlign.center, style: t.bodyLarge),
              const SizedBox(height: 4),
              Text(
                b.publicationYear == null
                    ? b.id
                    : '${b.id}  ·  ${b.publicationYear}',
                textAlign: TextAlign.center,
                style: t.bodySmall,
              ),
              if (genres.isNotEmpty) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.center,
                  child: GenreTags(genres: genres, maxShown: genres.length),
                ),
              ],
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: stockColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          out
                              ? 'No copies available right now'
                              : '${b.availableCopies} of ${b.totalCopies} ${b.totalCopies == 1 ? 'copy' : 'copies'} available',
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('About this book', style: t.titleLarge),
              const SizedBox(height: 8),
              Text(
                b.description.isEmpty
                    ? 'No description provided.'
                    : b.description,
                style: b.description.isEmpty
                    ? t.bodySmall
                    : t.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ElevatedButton(
                      onPressed: null,
                      child: Text('Reserve'),
                    ),
                    const SizedBox(height: 6),
                    Text('Reservations are coming soon.', style: t.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
