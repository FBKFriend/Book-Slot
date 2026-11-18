import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_colors.dart';
import 'book_cover.dart';

/// Cover-on-top card used by the student Catalog grid.
class BookGridCard extends StatelessWidget {
  final Book book;
  final double width;
  final VoidCallback onTap;
  const BookGridCard({
    super.key,
    required this.book,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final out = book.availableCopies == 0;
    final stockColor = out ? const Color(0xFFE57373) : const Color(0xFF7FB77E);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(
            bookId: book.id,
            version: book.coverVersion,
            width: width,
            height: width * 1.5,
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.titleSmall?.copyWith(
              color: AppColors.heading,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall,
          ),
          const SizedBox(height: 4),
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
                  out ? 'Unavailable' : '${book.availableCopies} available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: stockColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
