import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

const int _maxStoredBytes = 900000; // Firestore documents max out near 1 MiB

class EvidencePick {
  final Uint8List? bytes;
  final String? error;
  const EvidencePick.ok(this.bytes) : error = null;
  const EvidencePick.fail(this.error) : bytes = null;
}

/// Takes or picks a photo and shrinks it so it fits in a Firestore document.
/// Returns null if the user cancelled.
Future<EvidencePick?> pickEvidencePhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 80,
  );
  if (file == null) return null;

  final raw = await file.readAsBytes();
  final out = await compute(_shrink, raw);
  if (out == null) {
    return const EvidencePick.fail(
      'Could not read that photo. Please try again.',
    );
  }
  if (out.length > _maxStoredBytes) {
    return const EvidencePick.fail(
      'That photo is too detailed. Try another one.',
    );
  }
  return EvidencePick.ok(out);
}

// Runs in a background isolate so the UI doesn't freeze
Uint8List? _shrink(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);

  const maxSide = 1280;
  final longest = max(image.width, image.height);
  if (longest > maxSide) {
    final scale = maxSide / longest;
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  var quality = 80;
  var bytes = img.encodeJpg(image, quality: quality);
  while (bytes.length > 850000 && quality > 40) {
    quality -= 10;
    bytes = img.encodeJpg(image, quality: quality);
  }
  return Uint8List.fromList(bytes);
}
