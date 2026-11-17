import 'package:flutter/material.dart';

import 'books_tab.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

class LibrarianShell extends StatefulWidget {
  final AppUser user;
  const LibrarianShell({super.key, required this.user});

  @override
  State<LibrarianShell> createState() => _LibrarianShellState();
}

class _LibrarianShellState extends State<LibrarianShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    _TabPlaceholder(title: 'Dashboard', user: widget.user),
    BooksTab(user: widget.user),
    const _TabPlaceholder(title: 'QR Scanner'),
    const _TabPlaceholder(title: 'Borrowing & Reservations'),
    const _TabPlaceholder(title: 'Transaction History'),
  ];

  Widget _scanIcon() => Container(
    padding: const EdgeInsets.all(4),
    decoration: const BoxDecoration(
      color: AppColors.gold,
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.qr_code_scanner,
      color: AppColors.background,
      size: 22,
    ),
  );

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
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            const NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Books',
            ),
            NavigationDestination(
              icon: _scanIcon(),
              selectedIcon: _scanIcon(),
              label: 'Scan',
            ),
            const NavigationDestination(
              icon: Icon(Icons.bookmarks_outlined),
              selectedIcon: Icon(Icons.bookmarks),
              label: 'Borrowing',
            ),
            const NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  final String title;
  final AppUser? user; // only the Dashboard shows the account button
  const _TabPlaceholder({required this.title, this.user});

  void _showAccount(BuildContext context, AppUser u) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.name.isEmpty ? 'Librarian' : u.name,
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
                const SizedBox(height: 4),
                Text('Librarian', style: t.bodySmall),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    AuthService.instance.signOut();
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Account',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => _showAccount(context, user!),
            ),
        ],
      ),
      body: Center(
        child: Text(
          'Coming soon',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
