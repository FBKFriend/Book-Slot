import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_colors.dart';
import 'book_cover.dart';
import 'genre_tags.dart';

class BookListCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  const BookListCard({super.key, required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final out = book.availableCopies == 0;
    final stockColor = out ? const Color(0xFFE57373) : const Color(0xFF7FB77E);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(
                bookId: book.id,
                version: book.coverVersion,
                width: 64,
                height: 96,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        color: AppColors.heading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium,
                    ),
                    if (book.publicationYear != null) ...[
                      const SizedBox(height: 2),
                      Text('${book.publicationYear}', style: t.bodySmall),
                    ],
                    if (book.genres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GenreTags(genres: book.genres),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: stockColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            out
                                ? 'Unavailable'
                                : '${book.availableCopies} of ${book.totalCopies} available',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: stockColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
