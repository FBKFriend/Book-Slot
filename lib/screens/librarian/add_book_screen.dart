import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_user.dart';
import '../../services/book_service.dart';
import '../../services/cover_image.dart';
import '../../theme/app_colors.dart';
import '../../widgets/genre_picker.dart';

class AddBookScreen extends StatefulWidget {
  final AppUser user;
  const AddBookScreen({super.key, required this.user});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _description = TextEditingController();
  final _year = TextEditingController();
  final _copies = TextEditingController(text: '1');

  Set<String> _genres = {};
  Uint8List? _cover;
  String? _coverError;
  bool _pickingCover = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _description.dispose();
    _year.dispose();
    _copies.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    setState(() {
      _pickingCover = true;
      _coverError = null;
    });
    final r = await pickCoverImage();
    if (!mounted) return;
    setState(() {
      _pickingCover = false;
      if (r == null) return; // cancelled
      if (r.error != null) {
        _coverError = r.error;
      } else {
        _cover = r.bytes;
      }
    });
  }

  Future<void> _chooseGenres() async {
    final r = await showGenrePicker(context, selected: _genres);
    if (r != null) setState(() => _genres = r);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await BookService.instance.addBook(
        actorRole: widget.user.role,
        title: _title.text,
        author: _author.text,
        description: _description.text,
        genres: _genres.toList()..sort(),
        publicationYear: int.tryParse(_year.text.trim()),
        totalCopies: int.parse(_copies.text.trim()),
        cover: _cover,
      );
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('Added $id')));
    } catch (e) {
      debugPrint('addBook failed: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not add the book. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sortedGenres = _genres.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Add book')),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickingCover ? null : _pickCover,
                child: Container(
                  width: 140,
                  height: 210,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _pickingCover
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _cover != null
                      ? Image.memory(_cover!, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: AppColors.gold,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text('Add cover', style: t.bodySmall),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('JPG or PNG, up to 2 MB', style: t.bodySmall)),
            if (_cover != null)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _cover = null),
                  child: const Text('Remove cover'),
                ),
              ),
            if (_coverError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _coverError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE57373)),
                ),
              ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _author,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Author'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Publication year',
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return null;
                      final n = int.tryParse(s);
                      final max = DateTime.now().year + 1;
                      return (n != null && n >= 1000 && n <= max)
                          ? null
                          : 'Invalid year';
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _copies,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Total copies',
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return (n != null && n >= 1 && n <= 1000)
                          ? null
                          : '1 to 1000';
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Genres', style: t.bodySmall),
            const SizedBox(height: 8),
            if (sortedGenres.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in sortedGenres)
                      InputChip(
                        label: Text(g),
                        onDeleted: () => setState(() => _genres.remove(g)),
                      ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                ),
                onPressed: _chooseGenres,
                icon: const Icon(Icons.label_outline, size: 18),
                label: Text(
                  sortedGenres.isEmpty ? 'Choose genres' : 'Edit genres',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: Color(0xFFE57373))),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add book'),
            ),
          ],
        ),
      ),
    );
  }
}
