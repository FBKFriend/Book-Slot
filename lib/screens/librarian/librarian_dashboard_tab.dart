import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_user.dart';
import '../../models/dashboard_stats.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../theme/app_colors.dart';

class LibrarianDashboardTab extends StatefulWidget {
  final AppUser user;
  final VoidCallback onOpenBorrowing; // jumps to the Borrowing tab
  const LibrarianDashboardTab({
    super.key,
    required this.user,
    required this.onOpenBorrowing,
  });

  @override
  State<LibrarianDashboardTab> createState() => _LibrarianDashboardTabState();
}

class _LibrarianDashboardTabState extends State<LibrarianDashboardTab> {
  late final Stream<DashboardStats> _stream = DashboardService.instance.watch();

  void _showAccount() {
    final u = widget.user;
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

  Widget _grid(List<Widget> children) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 1.05,
    children: children,
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: _showAccount,
          ),
        ],
      ),
      body: StreamBuilder<DashboardStats>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load the dashboard.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (s.pendingRequests > 0) ...[
                _AttentionBanner(
                  count: s.pendingRequests,
                  onTap: widget.onOpenBorrowing,
                ),
                const SizedBox(height: 16),
              ],
              Text('Library', style: t.titleLarge),
              const SizedBox(height: 10),
              _grid([
                _StatCard(
                  icon: Icons.menu_book_outlined,
                  label: 'Books in library',
                  value: '${s.titles}',
                  caption:
                      '${s.totalCopies} ${s.totalCopies == 1 ? 'copy' : 'copies'}',
                ),
                _StatCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Available now',
                  value: '${s.availableCopies}',
                  caption: s.heldCopies > 0
                      ? '${s.heldCopies} held for pickup'
                      : null,
                ),
                _StatCard(
                  icon: Icons.swap_horiz,
                  label: 'Borrowed now',
                  value: '${s.borrowedNow}',
                ),
                _StatCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Overdue',
                  value: '${s.overdue}',
                  alert: s.overdue > 0,
                ),
              ]),
              const SizedBox(height: 24),
              Text('Reservations', style: t.titleLarge),
              const SizedBox(height: 10),
              _grid([
                _StatCard(
                  icon: Icons.hourglass_top,
                  label: 'Pending requests',
                  value: '${s.pendingRequests}',
                  onTap: widget.onOpenBorrowing,
                ),
                _StatCard(
                  icon: Icons.bookmark_added_outlined,
                  label: 'Waiting for pickup',
                  value: '${s.awaitingPickup}',
                  onTap: widget.onOpenBorrowing,
                ),
              ]),
              const SizedBox(height: 24),
              Text('Today', style: t.titleLarge),
              const SizedBox(height: 10),
              _grid([
                _StatCard(
                  icon: Icons.north_east,
                  label: 'Borrowed today',
                  value: '${s.borrowedToday}',
                ),
                _StatCard(
                  icon: Icons.south_west,
                  label: 'Returned today',
                  value: '${s.returnedToday}',
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final bool alert; // red highlight, e.g. overdue books
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.alert = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = alert ? const Color(0xFFE57373) : AppColors.gold;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 22),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.playfairDisplay(
                  color: alert ? accent : AppColors.heading,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall,
              ),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _AttentionBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.gold),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top, color: AppColors.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$count reservation request${count == 1 ? '' : 's'} waiting for review.',
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
