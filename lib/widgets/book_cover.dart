import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/cover_service.dart';
import '../theme/app_colors.dart';

class BookCover extends StatefulWidget {
  final String bookId;
  final int version;
  final double width;
  final double height;

  const BookCover({
    super.key,
    required this.bookId,
    required this.version,
    this.width = 64,
    this.height = 96,
  });

  @override
  State<BookCover> createState() => _BookCoverState();
}

class _BookCoverState extends State<BookCover> {
  late Future<Uint8List?> _future = CoverService.instance.load(
    widget.bookId,
    widget.version,
  );

  @override
  void didUpdateWidget(covariant BookCover old) {
    super.didUpdateWidget(old);
    if (old.bookId != widget.bookId || old.version != widget.version) {
      _future = CoverService.instance.load(widget.bookId, widget.version);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FutureBuilder<Uint8List?>(
          future: _future,
          builder: (context, snap) {
            final bytes = snap.data;
            if (bytes != null) {
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            }
            return const Center(
              child: Icon(Icons.menu_book_outlined, color: AppColors.muted),
            );
          },
        ),
      ),
    );
  }
}
