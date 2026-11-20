import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_colors.dart';

/// Bottom sheet that shows a QR code for the librarian to scan.
Future<void> showQrSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String data,
  required String hint,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        _QrSheet(title: title, subtitle: subtitle, data: data, hint: hint),
  );
}

class _QrSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final String data;
  final String hint;
  const _QrSheet({
    required this.title,
    required this.subtitle,
    required this.data,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: t.bodySmall),
            const SizedBox(height: 16),
            // Always black on white, so scanners can read it in dark mode
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: data,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(hint, textAlign: TextAlign.center, style: t.bodySmall),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: AppColors.border),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
