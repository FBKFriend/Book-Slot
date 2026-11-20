import 'package:flutter/material.dart';

import 'library_tab.dart';
import 'alerts_tab.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
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

  late final Stream<List<AppNotification>> _notes = NotificationService.instance
      .watchFor(widget.user.email);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _notes,
      builder: (context, snap) {
        final notes = snap.data;
        final unread = notes?.where((n) => !n.isRead).length ?? 0;
        final pages = <Widget>[
          CatalogTab(user: widget.user),
          SearchTab(user: widget.user),
          LibraryTab(user: widget.user),
          AlertsTab(notes: notes, hasError: snap.hasError),
          _SettingsPlaceholder(user: widget.user),
        ];
        return Scaffold(
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories),
                  label: 'Catalog',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.search),
                  selectedIcon: Icon(Icons.search),
                  label: 'Search',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.bookmarks_outlined),
                  selectedIcon: Icon(Icons.bookmarks),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications),
                  ),
                  label: 'Alerts',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        );
      },
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
