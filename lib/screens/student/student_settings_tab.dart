import 'package:flutter/material.dart';

import 'student_history_screen.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/genre_picker.dart';
import '../../widgets/genre_tags.dart';

class StudentSettingsTab extends StatefulWidget {
  final AppUser user;
  const StudentSettingsTab({super.key, required this.user});

  @override
  State<StudentSettingsTab> createState() => _StudentSettingsTabState();
}

class _StudentSettingsTabState extends State<StudentSettingsTab> {
  bool _saving = false;

  Future<void> _editGenres() async {
    final picked = await showGenrePicker(
      context,
      selected: widget.user.preferredGenres.toSet(),
      title: 'Preferred genres',
    );
    if (picked == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await UserService.instance.savePreferredGenres(
        widget.user.email,
        picked.toList()..sort(),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Preferred genres saved')),
      );
    } catch (e) {
      debugPrint('save genres failed: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final u = widget.user;
    final genres = [...u.preferredGenres]..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.name.isEmpty ? 'Student' : u.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    u.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall,
                  ),
                  if ((u.studentId ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(u.studentId!, style: t.bodySmall),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Preferences', style: t.titleLarge),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _saving ? null : _editGenres,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preferred genres',
                            style: TextStyle(
                              color: AppColors.heading,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Used for the recommendations in the Menu',
                            style: t.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          if (genres.isEmpty)
                            Text('None selected', style: t.bodySmall)
                          else
                            GenreTags(genres: genres, maxShown: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentHistoryScreen(user: widget.user),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: AppColors.gold),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'History',
                            style: TextStyle(
                              color: AppColors.heading,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your reservations and borrowed books',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.border),
            ),
            onPressed: () => AuthService.instance.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
