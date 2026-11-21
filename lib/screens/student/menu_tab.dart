import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/book.dart';
import '../../services/book_service.dart';
import '../../widgets/book_grid_card.dart';
import 'book_detail_screen.dart';

class MenuTab extends StatefulWidget {
  final AppUser user;
  const MenuTab({super.key, required this.user});

  @override
  State<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> {
  static const _maxRecommended = 10;

  late final Stream<List<Book>> _stream = BookService.instance.watchBooks();

  // Fixed for this session, so the picks don't reshuffle on every update
  final int _seed = Random().nextInt(1 << 30);
  int _shuffleKey(Book b) => Object.hash(b.id, _seed);

  ({List<Book> books, String note}) _recommend(List<Book> all) {
    final prefs = widget.user.preferredGenres.toSet();

    if (prefs.isNotEmpty) {
      final scored = <(Book, int)>[];
      for (final b in all) {
        final matches = b.genres.where(prefs.contains).length;
        if (matches > 0) scored.add((b, matches));
      }
      if (scored.isNotEmpty) {
        // More matching genres first; ties in a random (but stable) order
        scored.sort((a, b) {
          final byMatch = b.$2.compareTo(a.$2);
          return byMatch != 0
              ? byMatch
              : _shuffleKey(a.$1).compareTo(_shuffleKey(b.$1));
        });
        return (
          books: scored.take(_maxRecommended).map((e) => e.$1).toList(),
          note: 'Based on your favorite genres',
        );
      }
    }

    final shuffled = [...all]
      ..sort((a, b) => _shuffleKey(a).compareTo(_shuffleKey(b)));
    return (
      books: shuffled.take(_maxRecommended).toList(),
      note: prefs.isEmpty
          ? 'Random picks. Choose your favorite genres in Settings for better ones.'
          : 'Random picks. No books match your favorite genres yet.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
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

          final rec = _recommend(books);
          return LayoutBuilder(
            builder: (context, c) {
              const pad = 16.0;
              const gap = 12.0;
              final gridW = (c.maxWidth - pad * 2 - gap) / 2;
              // About 3 cards fit, with a peek of the next one
              final railW = (c.maxWidth - pad - 2 * 10) / 3.25;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(pad, 12, pad, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recommended for you', style: t.titleLarge),
                          const SizedBox(height: 2),
                          Text(rec.note, style: t.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: railW * 1.5 + 96 + 12,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(pad, 12, pad, 0),
                        itemCount: rec.books.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, i) => SizedBox(
                          width: railW,
                          child: BookGridCard(
                            book: rec.books[i],
                            width: railW,
                            onTap: () => openBookDetail(
                              context,
                              rec.books[i],
                              widget.user,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(pad, 24, pad, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Catalog', style: t.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            '${books.length} ${books.length == 1 ? 'book' : 'books'}',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(pad, 12, pad, 24),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: gap,
                        mainAxisExtent: gridW * 1.5 + 96,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => BookGridCard(
                          book: books[i],
                          width: gridW,
                          onTap: () =>
                              openBookDetail(context, books[i], widget.user),
                        ),
                        childCount: books.length,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
