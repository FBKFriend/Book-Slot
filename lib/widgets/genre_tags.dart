import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GenreTags extends StatelessWidget {
  final List<String> genres;
  final int maxShown;
  const GenreTags({super.key, required this.genres, this.maxShown = 4});

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();
    final shown = genres.take(maxShown).toList();
    final extra = genres.length - shown.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final g in shown) _Tag(g),
        if (extra > 0) _Tag('+$extra'),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.body),
      ),
    );
  }
}
