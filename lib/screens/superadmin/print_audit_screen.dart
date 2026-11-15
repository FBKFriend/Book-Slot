import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/audit_entry.dart';
import '../../services/audit_pdf.dart';
import '../../services/audit_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_range.dart';
import '../../utils/format.dart';
import '../../widgets/filter_dropdown.dart';

class PrintAuditScreen extends StatefulWidget {
  const PrintAuditScreen({super.key});

  @override
  State<PrintAuditScreen> createState() => _PrintAuditScreenState();
}

class _PrintAuditScreenState extends State<PrintAuditScreen> {
  String _preset = 'month';
  String _entity = 'all';
  DateTime? _from;
  DateTime? _to;
  bool _busy = false;

  bool get _bothPicked => _from != null && _to != null;

  // From must be strictly earlier than To
  bool get _rangeOk => _bothPicked && _from!.isBefore(_to!);

  bool get _showOrderError => _preset == 'custom' && _bothPicked && !_rangeOk;

  bool get _canPrint => _preset == 'custom' ? _rangeOk : true;

  Future<void> _pick({required bool isFrom}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? today,
      firstDate: DateTime(2025, 1, 1),
      lastDate: today,
      helpText: isFrom ? 'From date' : 'To date',
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  String _periodLabel(DateBounds r) {
    if (r.start == null || r.endExclusive == null) return 'All time';
    final e = r.endExclusive!;
    final last = DateTime(e.year, e.month, e.day - 1);
    final a = formatDate(r.start!);
    final b = formatDate(last);
    final span = a == b ? a : '$a to $b';
    return _preset == 'custom'
        ? span
        : '${kDatePresetOptions[_preset]} ($span)';
  }

  Future<void> _print() async {
    final messenger = ScaffoldMessenger.of(context);
    final r = resolveRange(_preset, from: _from, to: _to);
    setState(() => _busy = true);
    try {
      final all = await AuditService.instance.fetchRange(
        start: r.start,
        endExclusive: r.endExclusive,
      );
      final entries = _entity == 'all'
          ? all
          : all.where((e) => e.actorRole == _entity).toList();
      if (entries.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No log entries for this selection.')),
        );
        return;
      }
      final me = FirebaseAuth.instance.currentUser;
      final who = (me?.displayName ?? '').isNotEmpty
          ? me!.displayName!
          : (me?.email ?? 'superadmin');
      final bytes = await buildAuditPdf(
        entries: entries,
        periodLabel: _periodLabel(r),
        generatedBy: who,
        doneByLabel: kAuditActorOptions[_entity]!,
      );
      await Printing.layoutPdf(
        name: 'bookslot-audit-log',
        onLayout: (format) async => bytes,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not create the PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _dateButton({required bool isFrom}) {
    final value = isFrom ? _from : _to;
    final label = isFrom ? 'From' : 'To';
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.border),
      ),
      onPressed: () => _pick(isFrom: isFrom),
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(
        value == null ? label : '$label: ${formatDate(value)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Print audit log')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Choose the period to include in the PDF.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterDropdown(
                label: 'Show',
                value: _entity,
                options: kAuditActorOptions,
                onChanged: (v) => setState(() => _entity = v),
              ),
              FilterDropdown(
                label: 'Period',
                value: _preset,
                options: kDatePresetOptions,
                onChanged: (v) => setState(() => _preset = v),
              ),
            ],
          ),
          if (_preset == 'custom') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dateButton(isFrom: true)),
                const SizedBox(width: 12),
                Expanded(child: _dateButton(isFrom: false)),
              ],
            ),
            if (_showOrderError)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'The From date must be earlier than the To date.',
                  style: TextStyle(color: Color(0xFFE57373)),
                ),
              ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_canPrint && !_busy) ? _print : null,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Print PDF'),
          ),
        ],
      ),
    );
  }
}
