import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../models/app_user.dart';
import '../../models/system_settings.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_colors.dart';

class SettingsTab extends StatefulWidget {
  final AppUser user;
  const SettingsTab({super.key, required this.user});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late final Stream<SystemSettings> _stream = SettingsService.instance.watch();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Settings')),
      body: StreamBuilder<SystemSettings>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load settings.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _SettingsBody(saved: snap.data!, user: widget.user);
        },
      ),
    );
  }
}

class _SettingsBody extends StatefulWidget {
  final SystemSettings saved;
  final AppUser user;
  const _SettingsBody({required this.saved, required this.user});

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  late SystemSettings _draft = widget.saved;
  bool _saving = false;

  bool get _dirty => !_draft.sameAs(widget.saved);

  @override
  void didUpdateWidget(covariant _SettingsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If nothing is being edited, follow changes made from another device
    if (_draft.sameAs(oldWidget.saved)) _draft = widget.saved;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await SettingsService.instance.save(_draft);
      messenger.showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Borrowing rules', style: t.titleLarge),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _StepperRow(
                  label: 'Default borrowing duration',
                  hint: 'How long a student keeps a book',
                  unit: 'day',
                  value: _draft.borrowDays,
                  min: 1,
                  max: 60,
                  onChanged: (v) =>
                      setState(() => _draft = _draft.copyWith(borrowDays: v)),
                ),
                const Divider(color: AppColors.border),
                _StepperRow(
                  label: 'Max books borrowed at once',
                  hint: 'Per student',
                  unit: 'book',
                  value: _draft.maxBorrowedBooks,
                  min: 1,
                  max: 20,
                  onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(maxBorrowedBooks: v),
                  ),
                ),
                const Divider(color: AppColors.border),
                _StepperRow(
                  label: 'Reservation pickup deadline',
                  hint: 'Time to collect an approved book',
                  unit: 'day',
                  value: _draft.pickupDeadlineDays,
                  min: 1,
                  max: 14,
                  onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(pickupDeadlineDays: v),
                  ),
                ),
                const Divider(color: AppColors.border),
                _StepperRow(
                  label: 'Max active reservations',
                  hint: 'Pending or approved requests per student',
                  unit: 'request',
                  value: _draft.maxActiveReservations,
                  min: 1,
                  max: 20,
                  onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(maxActiveReservations: v),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: (_dirty && !_saving) ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save changes'),
        ),
        const SizedBox(height: 28),
        Text('System info', style: t.titleLarge),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const _KeyValue('App', kAppName),
                const _KeyValue('Version', kAppVersion),
                _KeyValue('Firebase project', Firebase.app().options.projectId),
                _KeyValue('Signed in as', widget.user.email),
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
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final String hint;
  final String unit;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _StepperRow({
    required this.label,
    required this.hint,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.heading,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(hint, style: t.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: t.titleMedium?.copyWith(color: AppColors.heading),
                ),
                Text('$unit${value == 1 ? '' : 's'}', style: t.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValue(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
