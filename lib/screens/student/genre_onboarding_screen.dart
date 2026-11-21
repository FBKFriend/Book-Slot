import 'package:flutter/material.dart';

import '../../data/genres.dart';
import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';

/// Shown once, the first time an authorized student opens the app.
class GenreOnboardingScreen extends StatefulWidget {
  final AppUser user;
  const GenreOnboardingScreen({super.key, required this.user});

  @override
  State<GenreOnboardingScreen> createState() => _GenreOnboardingScreenState();
}

class _GenreOnboardingScreenState extends State<GenreOnboardingScreen> {
  final Set<String> _picked = {};
  final _search = TextEditingController();
  String _q = '';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> genres) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await UserService.instance.savePreferredGenres(widget.user.email, genres);
      // The account gate sees the change and opens the app by itself
    } catch (e) {
      debugPrint('save genres failed: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final first = widget.user.nameParts.first;
    final shown = kGenres.where((g) => g.toLowerCase().contains(_q)).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    first.isEmpty ? 'Welcome!' : 'Welcome, $first!',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('What do you like to read?', style: t.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Pick your favorite genres. We use them to recommend books in the Menu. This is optional, and you can change it anytime in Settings.',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search genres',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) =>
                        setState(() => _q = v.trim().toLowerCase()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: shown.isEmpty
                    ? Text('No genres match', style: t.bodySmall)
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final g in shown)
                            FilterChip(
                              label: Text(g),
                              selected: _picked.contains(g),
                              selectedColor: AppColors.gold.withValues(
                                alpha: 0.2,
                              ),
                              checkmarkColor: AppColors.gold,
                              side: BorderSide(
                                color: _picked.contains(g)
                                    ? AppColors.gold
                                    : AppColors.border,
                              ),
                              onSelected: _saving
                                  ? null
                                  : (v) => setState(() {
                                      if (v) {
                                        _picked.add(g);
                                      } else {
                                        _picked.remove(g);
                                      }
                                    }),
                            ),
                        ],
                      ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFE57373)),
                      ),
                    ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => _save(const <String>[]),
                        child: const Text('Skip'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_saving || _picked.isEmpty)
                              ? null
                              : () => _save(_picked.toList()..sort()),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _picked.isEmpty
                                      ? 'Continue'
                                      : 'Continue (${_picked.length})',
                                ),
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
    );
  }
}
