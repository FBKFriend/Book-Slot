import 'package:flutter/material.dart';

import 'library_tab.dart';
import 'alerts_tab.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import 'menu_tab.dart';
import 'search_tab.dart';
import '../../models/app_user.dart';
import 'student_settings_tab.dart';
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
          MenuTab(user: widget.user),
          SearchTab(user: widget.user),
          LibraryTab(user: widget.user),
          AlertsTab(user: widget.user, notes: notes, hasError: snap.hasError),
          StudentSettingsTab(user: widget.user),
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
                  label: 'Menu',
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
