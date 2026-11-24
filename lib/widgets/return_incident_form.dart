import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/return_incident.dart';
import '../services/evidence_image.dart';
import '../theme/app_colors.dart';

/// "Fine and condition" section of the return sheet.
/// Calls [onChanged] with what the librarian entered and whether it is complete.
class ReturnIncidentForm extends StatefulWidget {
  final int daysLate; // 0 = returned on time
  final void Function(ReturnIncident? incident, bool valid) onChanged;
  const ReturnIncidentForm({
    super.key,
    required this.daysLate,
    required this.onChanged,
  });

  @override
  State<ReturnIncidentForm> createState() => _ReturnIncidentFormState();
}

class _ReturnIncidentFormState extends State<ReturnIncidentForm> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _damaged = false;
  String? _condition;
  Uint8List? _photo;
  bool _picking = false;
  String? _photoError;

  bool get _late => widget.daysLate > 0;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _notify() {
    final text = _amount.text.trim();
    final amount = int.tryParse(text);
    final hasAmount = amount != null && amount > 0;
    final reason = _reason.text.trim();

    final bool valid;
    if (_damaged) {
      // A damaged book needs everything, including a fine
      valid =
          hasAmount &&
          reason.isNotEmpty &&
          _condition != null &&
          _photo != null;
    } else {
      // A late fine is optional, but if something is typed it must be real
      valid = text.isEmpty || hasAmount;
    }

    ReturnIncident? incident;
    if (_damaged || hasAmount) {
      incident = ReturnIncident(
        fineAmount: hasAmount ? amount : null,
        damaged: _damaged,
        damageReason: reason,
        condition: _damaged ? _condition : null,
        photo: _damaged ? _photo : null,
      );
    }
    widget.onChanged(incident, valid);
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() {
      _picking = true;
      _photoError = null;
    });
    final r = await pickEvidencePhoto(source);
    if (!mounted) return;
    setState(() {
      _picking = false;
      if (r == null) return; // cancelled
      if (r.error != null) {
        _photoError = r.error;
      } else {
        _photo = r.bytes;
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const red = Color(0xFFE57373);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.border, height: 28),
        Text(
          'Fine and condition',
          style: t.titleMedium?.copyWith(
            color: AppColors.heading,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_late)
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: red),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Returned ${widget.daysLate} ${widget.daysLate == 1 ? 'day' : 'days'} late. You can add a fine.',
                  style: const TextStyle(color: red, fontSize: 13),
                ),
              ),
            ],
          )
        else
          Text(
            'Returned on time. Nothing to do unless the book is damaged.',
            style: t.bodySmall,
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Book is damaged'),
          value: _damaged,
          onChanged: (v) {
            setState(() {
              _damaged = v;
              if (!v && !_late) _amount.clear();
            });
            _notify();
          },
        ),
        if (_damaged) ...[
          Text(
            'A photo, the reason, the condition and a fine are required.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _picking ? null : _pickPhoto,
            child: Container(
              height: 150,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _picking
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _photo != null
                  ? Image.memory(_photo!, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.gold,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text('Add a photo of the damage', style: t.bodySmall),
                      ],
                    ),
            ),
          ),
          if (_photo != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _picking ? null : _pickPhoto,
                child: const Text('Change photo'),
              ),
            ),
          if (_photoError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_photoError!, style: const TextStyle(color: red)),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What is wrong with the book?',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => _notify(),
          ),
          const SizedBox(height: 8),
          Text('Condition', style: t.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final c in const [
                ('functional', 'Still functional'),
                ('discarded', 'To be discarded'),
              ])
                ChoiceChip(
                  label: Text(c.$2),
                  selected: _condition == c.$1,
                  selectedColor: AppColors.gold.withValues(alpha: 0.2),
                  onSelected: (_) {
                    setState(() => _condition = c.$1);
                    _notify();
                  },
                ),
            ],
          ),
          if (_condition == 'discarded')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'The book will be removed from the total copies (1 copy less).',
                style: t.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
        ],
        if (_late || _damaged)
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: _damaged
                  ? 'Fine amount (required)'
                  : 'Fine amount (optional)',
              prefixText: '₱ ',
              helperText: 'Whole pesos',
            ),
            onChanged: (_) => _notify(),
          ),
      ],
    );
  }
}
