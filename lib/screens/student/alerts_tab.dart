import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';

class AlertsTab extends StatelessWidget {
  /// null = still loading
  final List<AppNotification>? notes;
  final bool hasError;
  const AlertsTab({super.key, required this.notes, required this.hasError});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final list = notes;
    final hasUnread = list?.any((n) => !n.isRead) ?? false;

    Widget body;
    if (hasError) {
      body = const Center(child: Text('Could not load notifications.'));
    } else if (list == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (list.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No notifications yet. You will be notified here when the librarian responds to your reservations.',
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _AlertCard(list[i]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            IconButton(
              tooltip: 'Mark all as read',
              icon: const Icon(Icons.done_all),
              onPressed: () => NotificationService.instance.markAllRead(list!),
            ),
        ],
      ),
      body: body,
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
