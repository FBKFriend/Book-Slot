import 'package:flutter/material.dart';

import '../../models/audit_entry.dart';
import '../../services/audit_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format.dart';
import '../../widgets/filter_dropdown.dart';

class AuditTab extends StatefulWidget {
  const AuditTab({super.key});

  @override
  State<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<AuditTab> {
  late final Stream<List<AuditEntry>> _stream = AuditService.instance
      .watchLatest();
  String _category = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterDropdown(
                label: 'Category',
                value: _category,
                options: const {
                  'all': 'All',
                  'accounts': 'Accounts',
                  'settings': 'Settings',
                },
                onChanged: (v) => setState(() => _category = v),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AuditEntry>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Could not load the logs.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                final entries = _category == 'all'
                    ? all
                    : all.where((e) => e.category == _category).toList();
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      all.isEmpty
                          ? 'No log entries yet'
                          : 'No entries in this category',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) => _AuditCard(entries[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AuditEntry e;
  const _AuditCard(this.e);

  static (String, IconData) _look(String action) {
    switch (action) {
      case 'account.authorize':
        return ('Authorized account', Icons.verified_user_outlined);
      case 'account.reject':
        return ('Rejected registration', Icons.person_off_outlined);
      case 'account.suspend':
        return ('Suspended account', Icons.block);
      case 'account.reactivate':
        return ('Reactivated account', Icons.restart_alt);
      case 'account.add_librarian':
        return ('Added librarian', Icons.person_add_alt_1_outlined);
      case 'account.edit':
        return ('Edited user information', Icons.edit_outlined);
      case 'account.role_change':
        return ('Changed role', Icons.swap_horiz);
      case 'settings.update':
        return ('Updated system settings', Icons.tune);
      default:
        return (action, Icons.receipt_long_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (title, icon) = _look(e.action);
    final actor = e.actorName.isEmpty ? e.actorEmail : e.actorName;
    final hasName = (e.targetName ?? '').isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.background,
              child: Icon(icon, color: AppColors.gold, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'By $actor (${e.actorRole})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall,
                  ),
                  if (e.targetEmail != null) ...[
                    Text(
                      hasName
                          ? 'Account: ${e.targetName}'
                          : 'Account: ${e.targetEmail}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall,
                    ),
                    if (hasName)
                      Text(
                        e.targetEmail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
                  ],
                  if ((e.details ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(e.details!),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    e.createdAt == null
                        ? 'Just now'
                        : formatDateTime(e.createdAt!),
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
