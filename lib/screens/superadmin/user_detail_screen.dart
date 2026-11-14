import 'package:flutter/material.dart';

import 'user_forms.dart';
import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/status_chip.dart';

class UserDetailScreen extends StatefulWidget {
  final String email;
  const UserDetailScreen({super.key, required this.email});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late final Stream<AppUser?> _stream = UserService.instance.watchUser(
    widget.email,
  );

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  String _date(DateTime? d) {
    if (d == null) return '—';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('User details')),
      body: StreamBuilder<AppUser?>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load this user.'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final u = snap.data;
          if (u == null) {
            return Center(
              child: Text('This record no longer exists.', style: t.bodySmall),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                u.name.isEmpty ? u.email : u.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                u.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(status: u.status),
              ),
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow('Role', u.role),
                      if (u.role == 'student') ...[
                        _InfoRow('Student ID', u.studentId),
                        _InfoRow('Age', u.age?.toString()),
                        _InfoRow('Sex', u.sex),
                        _InfoRow('Course', u.course),
                      ],
                      if (u.role == 'student') ...[
                        _InfoRow('Registered', _date(u.createdAt)),
                        _InfoRow('Authorized', _date(u.authorizedAt)),
                      ] else
                        _InfoRow('Date created', _date(u.createdAt)),
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
                onPressed: () => showEditUserSheet(context, u),
                child: const Text('Edit information'),
              ),
              const SizedBox(height: 12),
              ..._actions(u),
              if (u.status != 'pending') ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _changeRole(u),
                  child: Text(
                    u.role == 'student' ? 'Make librarian' : 'Make student',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeRole(AppUser u) async {
    final newRole = u.role == 'student' ? 'librarian' : 'student';
    final ok = await _confirm(
      'Change role?',
      'This account will become a $newRole.',
      'Change',
    );
    if (!ok) return;
    await _run(() => UserService.instance.setRole(u.email, newRole));
  }

  List<Widget> _actions(AppUser u) {
    switch (u.status) {
      case 'pending':
        return [
          ElevatedButton(
            onPressed: () =>
                _run(() => UserService.instance.authorize(u.email)),
            child: const Text('Authorize'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.border),
              foregroundColor: const Color(0xFFE57373),
            ),
            onPressed: () async {
              final ok = await _confirm(
                'Reject registration?',
                'This deletes the registration. The student can sign up again with corrected information.',
                'Reject',
              );
              if (!ok) return;
              await _run(() => UserService.instance.deleteUser(u.email));
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Reject registration'),
          ),
        ];
      case 'active':
        return [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.border),
              foregroundColor: const Color(0xFFE57373),
            ),
            onPressed: () async {
              final ok = await _confirm(
                'Suspend account?',
                'They will lose access to the app until you reactivate them.',
                'Suspend',
              );
              if (!ok) return;
              await _run(
                () => UserService.instance.setStatus(u.email, 'suspended'),
              );
            },
            child: const Text('Suspend account'),
          ),
        ];
      default:
        return [
          ElevatedButton(
            onPressed: () =>
                _run(() => UserService.instance.setStatus(u.email, 'active')),
            child: const Text('Reactivate account'),
          ),
        ];
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final text = (value == null || value!.isEmpty) ? '—' : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: t.bodySmall)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
