import 'package:flutter/material.dart';

import '../data/genres.dart';
import '../theme/app_colors.dart';

/// Returns the checked genres, or null if cancelled.
Future<Set<String>?> showGenrePicker(
  BuildContext context, {
  required Set<String> selected,
  String title = 'Select genres',
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => _GenrePickerDialog(initial: selected, title: title),
  );
}

class _GenrePickerDialog extends StatefulWidget {
  final Set<String> initial;
  final String title;
  const _GenrePickerDialog({required this.initial, required this.title});

  @override
  State<_GenrePickerDialog> createState() => _GenrePickerDialogState();
}

class _GenrePickerDialogState extends State<_GenrePickerDialog> {
  late final Set<String> _picked = {...widget.initial};
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final shown = kGenres.where((g) => g.toLowerCase().contains(_q)).toList();

    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: t.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search genres',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final g in shown)
                      CheckboxListTile(
                        value: _picked.contains(g),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(g),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _picked.add(g);
                          } else {
                            _picked.remove(g);
                          }
                        }),
                      ),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No genres match', style: t.bodySmall),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: _picked.isEmpty
                        ? null
                        : () => setState(_picked.clear),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _picked),
                    child: Text('Apply (${_picked.length})'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
