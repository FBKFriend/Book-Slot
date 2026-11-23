import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A checkbox whose label has a tappable link, like
/// "I agree to the [Terms of Service]".
class LegalCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged; // null = disabled
  final String leading;
  final String linkText;
  final String trailing;
  final String? caption; // small line under the label
  final VoidCallback onOpen;

  const LegalCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.leading,
    required this.linkText,
    required this.onOpen,
    this.trailing = '',
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: leading),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: onOpen,
                          child: Text(
                            linkText,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.gold,
                            ),
                          ),
                        ),
                      ),
                      if (trailing.isNotEmpty) TextSpan(text: trailing),
                    ],
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(caption!, style: t.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
