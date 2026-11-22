import 'package:flutter/material.dart';

import 'librarian_dashboard_tab.dart';
import 'qr_scanner_tab.dart';
import 'history_tab.dart';
import 'borrowing_tab.dart';
import 'books_tab.dart';
import '../../models/app_user.dart';
import '../../theme/app_colors.dart';

class LibrarianShell extends StatefulWidget {
  final AppUser user;
  const LibrarianShell({super.key, required this.user});

  @override
  State<LibrarianShell> createState() => _LibrarianShellState();
}

class _LibrarianShellState extends State<LibrarianShell> {
  int _index = 0;

  // A getter, so the Borrowing tab knows when it becomes the visible tab
  List<Widget> get _pages => [
    LibrarianDashboardTab(
      user: widget.user,
      onOpenBorrowing: () => setState(() => _index = 3),
    ),
    BooksTab(user: widget.user),
    QrScannerTab(user: widget.user, active: _index == 2),
    BorrowingTab(user: widget.user, active: _index == 3),
    const HistoryTab(),
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
