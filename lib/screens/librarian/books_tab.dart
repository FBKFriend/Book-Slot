import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/book.dart';
import '../../services/book_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/genre_picker.dart';
import '../../widgets/genre_tags.dart';
import 'book_form_screen.dart';

class BooksTab extends StatefulWidget {
  final AppUser user;
  const BooksTab({super.key, required this.user});

  @override
  State<BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<BooksTab> {
  late final Stream<List<Book>> _stream = BookService.instance.watchBooks();
  final _search = TextEditingController();
  String _query = '';
  Set<String> _genres = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Book> _apply(List<Book> all) {
    final q = _query.trim().toLowerCase();
    return all.where((b) {
      final matchesText =
          q.isEmpty ||
          b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.id.toLowerCase().contains(q);
      final matchesGenre = _genres.isEmpty || b.genres.any(_genres.contains);
      return matchesText && matchesGenre;
    }).toList();
  }

  Future<void> _openFilter() async {
    final r = await showGenrePicker(
      context,
      selected: _genres,
      title: 'Filter by genre',
    );
    if (r != null) setState(() => _genres = r);
  }

  void _edit(Book b) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookFormScreen(user: widget.user, book: b),
      ),
    );
  }

  Future<void> _delete(Book b) async {
    final messenger = ScaffoldMessenger.of(context);

    if (b.availableCopies != b.totalCopies) {
      final out = b.totalCopies - b.availableCopies;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Can\'t delete this book'),
          content: Text(
            '$out ${out == 1 ? 'copy is' : 'copies are'} currently borrowed. '
            'A book can only be deleted when every copy is back in stock.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete book?'),
        content: Text(
          'This permanently removes "${b.title}" (${b.id}) and its cover.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await BookService.instance.deleteBook(
        actorRole: widget.user.role,
        id: b.id,
      );
      messenger.showSnackBar(SnackBar(content: Text('Deleted ${b.id}')));
    } on BookInUseException {
      messenger.showSnackBar(
        const SnackBar(content: Text('That book has copies borrowed.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete the book.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final selectedSorted = _genres.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Book Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BookFormScreen(user: widget.user)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add book'),
      ),
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
                      hintText: 'Search title, author, or ID',
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
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No books yet. Tap Add book to create the first one.',
                        textAlign: TextAlign.center,
                        style: t.bodySmall,
                      ),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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
                    return _BookCard(
                      book: b,
                      onEdit: () => _edit(b),
                      onDelete: () => _delete(b),
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

class _BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _BookCard({
    required this.book,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final out = book.availableCopies == 0;
    final stockColor = out ? const Color(0xFFE57373) : const Color(0xFF7FB77E);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
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
                    const SizedBox(height: 2),
                    Text(
                      book.publicationYear == null
                          ? book.id
                          : '${book.id}  ·  ${book.publicationYear}',
                      style: t.bodySmall,
                    ),
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
                                ? 'None available (0 of ${book.totalCopies})'
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
              PopupMenuButton<String>(
                tooltip: 'Options',
                color: AppColors.card,
                onSelected: (v) {
                  if (v == 'edit') {
                    onEdit();
                  } else {
                    onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit book')),
                  PopupMenuItem(value: 'delete', child: Text('Delete book')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
