import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/book.dart';
import '../../services/book_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/book_list_card.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/genre_picker.dart';
import 'book_detail_screen.dart';

class SearchTab extends StatefulWidget {
  final AppUser user;
  const SearchTab({super.key, required this.user});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  static const _sortOptions = {
    'title': 'Title (A–Z)',
    'newest': 'Newest',
    'available': 'Available first',
  };

  late final Stream<List<Book>> _stream = BookService.instance.watchBooks();
  final _search = TextEditingController();
  String _query = '';
  Set<String> _genres = {};
  String _sort = 'title';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _byTitle(Book a, Book b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  List<Book> _apply(List<Book> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((b) {
      final matchesText =
          q.isEmpty ||
          b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.id.toLowerCase().contains(q) ||
          b.genres.any((g) => g.toLowerCase().contains(q));
      final matchesGenre = _genres.isEmpty || b.genres.any(_genres.contains);
      return matchesText && matchesGenre;
    }).toList();

    switch (_sort) {
      case 'newest':
        // A missing date means the server timestamp hasn't arrived yet,
        // i.e. the book was added a moment ago.
        final now = DateTime.now();
        list.sort((a, b) {
          final byDate = (b.dateAdded ?? now).compareTo(a.dateAdded ?? now);
          return byDate != 0 ? byDate : _byTitle(a, b);
        });
      case 'available':
        list.sort((a, b) {
          final byStock = (b.availableCopies > 0 ? 1 : 0).compareTo(
            a.availableCopies > 0 ? 1 : 0,
          );
          return byStock != 0 ? byStock : _byTitle(a, b);
        });
      default:
        list.sort(_byTitle);
    }
    return list;
  }

  Future<void> _openFilter() async {
    final r = await showGenrePicker(
      context,
      selected: _genres,
      title: 'Filter by genre',
    );
    if (r != null) setState(() => _genres = r);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final selectedSorted = _genres.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Title, author, ID, or genre',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 10),
                Badge(
                  isLabelVisible: _genres.isNotEmpty,
                  label: Text('${_genres.length}'),
                  child: IconButton.outlined(
                    tooltip: 'Filter by genre',
                    icon: const Icon(Icons.filter_list),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    onPressed: _openFilter,
                  ),
                ),
              ],
            ),
          ),
          if (selectedSorted.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in selectedSorted)
                      InputChip(
                        label: Text(g),
                        onDeleted: () => setState(() => _genres.remove(g)),
                      ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterDropdown(
                label: 'Sort',
                value: _sort,
                options: _sortOptions,
                onChanged: (v) => setState(() => _sort = v),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Book>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Could not load books.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                if (all.isEmpty) {
                  return Center(
                    child: Text(
                      'No books in the library yet.',
                      style: t.bodySmall,
                    ),
                  );
                }
                final books = _apply(all);
                if (books.isEmpty) {
                  return Center(
                    child: Text(
                      'No books match your search',
                      style: t.bodySmall,
                    ),
                  );
                }
                return ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: books.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        '${books.length} ${books.length == 1 ? 'book' : 'books'}',
                        style: t.bodySmall,
                      );
                    }
                    final b = books[i - 1];
                    return BookListCard(
                      book: b,
                      onTap: () => openBookDetail(context, b, widget.user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
