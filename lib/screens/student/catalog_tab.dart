import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../services/book_service.dart';
import '../../widgets/book_grid_card.dart';
import 'book_detail_screen.dart';

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key});

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  late final Stream<List<Book>> _stream = BookService.instance.watchBooks();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog')),
      body: StreamBuilder<List<Book>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load books.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final books = snap.data!;
          if (books.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No books in the library yet.',
                  textAlign: TextAlign.center,
                  style: t.bodySmall,
                ),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, c) {
              const pad = 16.0;
              const gap = 12.0;
              final w = (c.maxWidth - pad * 2 - gap) / 2;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(pad, 12, pad, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: gap,
                  mainAxisExtent: w * 1.5 + 96,
                ),
                itemCount: books.length,
                itemBuilder: (context, i) => BookGridCard(
                  book: books[i],
                  width: w,
                  onTap: () => openBookDetail(context, books[i]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
