import 'package:flutter/material.dart';

import '../data/legal_text.dart';
import '../theme/app_colors.dart';

/// Pop-up with the full text of the Terms of Service or Privacy Policy.
Future<void> showLegalDialog(BuildContext context, LegalDocument doc) {
  return showDialog<void>(
    context: context,
    builder: (_) => _LegalDialog(doc: doc),
  );
}

class _LegalDialog extends StatelessWidget {
  final LegalDocument doc;
  const _LegalDialog({required this.doc});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doc.title, style: t.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Last updated: ${doc.updated}  ·  Version $kLegalVersion',
                style: t.bodySmall,
              ),
              const Divider(color: AppColors.border, height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < doc.sections.length; i++) ...[
                        Text(
                          '${i + 1}. ${doc.sections[i].heading}',
                          style: const TextStyle(
                            color: AppColors.heading,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          doc.sections[i].body,
                          style: t.bodyMedium?.copyWith(height: 1.5),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
