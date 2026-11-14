import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';

/// Temporary placeholder. Replaced by the real librarian UI later.
class LibrarianShell extends StatelessWidget {
  final AppUser user;
  const LibrarianShell({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Librarian')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.name.isEmpty ? 'Librarian' : user.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              user.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('Librarian UI coming soon', style: t.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => AuthService.instance.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
