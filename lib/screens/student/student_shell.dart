import 'package:flutter/material.dart';

import 'catalog_tab.dart';
import 'search_tab.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

class StudentShell extends StatefulWidget {
  final AppUser user;
  const StudentShell({super.key, required this.user});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    const CatalogTab(),
    const SearchTab(),
    const _TabPlaceholder(title: 'My Library'),
    const _TabPlaceholder(title: 'Notifications'),
    _SettingsPlaceholder(user: widget.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories),
              label: 'Catalog',
            ),
            NavigationDestination(
              icon: Icon(Icons.search),
              selectedIcon: Icon(Icons.search),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmarks_outlined),
              selectedIcon: Icon(Icons.bookmarks),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  final String title;
  const _TabPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'Coming soon',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// Temporary Settings tab: account info + sign out, so students can log out.
/// The light/dark toggle comes later.
class _SettingsPlaceholder extends StatelessWidget {
  final AppUser user;
  const _SettingsPlaceholder({required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
                    user.name.isEmpty ? 'Student' : user.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall,
                  ),
                  if ((user.studentId ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(user.studentId!, style: t.bodySmall),
                  ],
                ],
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
