import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/fine.dart';
import '../../services/fine_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import 'student_fines_list.dart';

class AlertsTab extends StatefulWidget {
  final AppUser user;

  /// null = still loading
  final List<AppNotification>? notes;
  final bool hasError;
  const AlertsTab({
    super.key,
    required this.user,
    required this.notes,
    required this.hasError,
  });

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  late final Stream<List<Fine>> _finesStream = FineService.instance
      .watchForStudent(widget.user.email);

  Widget _notesBody(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final list = widget.notes;
    if (widget.hasError) {
      return const Center(child: Text('Could not load notifications.'));
    }
    if (list == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No notifications yet. You will be notified here when the librarian responds to your reservations.',
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _AlertCard(list[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.notes;
    final hasUnread = list?.any((n) => !n.isRead) ?? false;
    final unreadCount = list?.where((n) => !n.isRead).length ?? 0;

    return StreamBuilder<List<Fine>>(
      stream: _finesStream,
      builder: (context, finesSnap) {
        final unpaid = finesSnap.data?.where((f) => !f.isPaid).length ?? 0;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Alerts'),
              actions: [
                if (hasUnread)
                  IconButton(
                    tooltip: 'Mark all as read',
                    icon: const Icon(Icons.done_all),
                    onPressed: () =>
                        NotificationService.instance.markAllRead(list!),
                  ),
              ],
              bottom: TabBar(
                dividerColor: AppColors.border,
                tabs: [
                  Tab(text: 'Notifications ($unreadCount)'),
                  Tab(text: 'Fines ($unpaid)'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _notesBody(context),
                StudentFinesList(
                  fines: finesSnap.data,
                  hasError: finesSnap.hasError,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AppNotification n;
  const _AlertCard(this.n);

  (IconData, Color) get _look {
    switch (n.type) {
      case 'reservation_accepted':
        return (Icons.check_circle_outline, const Color(0xFF7FB77E));
      case 'reservation_denied':
        return (Icons.cancel_outlined, const Color(0xFFE57373));
      case 'reservation_expired':
        return (Icons.timer_off_outlined, AppColors.gold);
      case 'reservation_dropped':
        return (Icons.remove_circle_outline, const Color(0xFFE57373));
      case 'fine_issued':
        return (Icons.request_quote_outlined, const Color(0xFFE57373));
      case 'fine_paid':
        return (Icons.paid_outlined, const Color(0xFF7FB77E));
      default:
        return (Icons.notifications_outlined, AppColors.gold);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (icon, color) = _look;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: n.isRead
            ? null
            : () => NotificationService.instance.markRead(n.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.background,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: TextStyle(
                        color: AppColors.heading,
                        fontWeight: n.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(n.message),
                    const SizedBox(height: 6),
                    Text(
                      n.createdAt == null
                          ? 'Just now'
                          : formatDateTime(n.createdAt!),
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!n.isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
