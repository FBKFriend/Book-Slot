import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

const int kMaxCoverPickBytes =
    2 * 1024 * 1024; // 2 MB limit on the chosen photo
const int _maxStoredBytes = 900000; // Firestore documents max out near 1 MiB

class CoverPick {
  final Uint8List? bytes;
  final String? error;
  const CoverPick.ok(this.bytes) : error = null;
  const CoverPick.fail(this.error) : bytes = null;
}

/// Returns null if the user cancelled.
Future<CoverPick?> pickCoverImage() async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (file == null) return null;

  final size = await file.length();
  if (size > kMaxCoverPickBytes) {
    final mb = (size / (1024 * 1024)).toStringAsFixed(1);
    return CoverPick.fail(
      'That photo is $mb MB. The limit is 2 MB, so please compress it and try again.',
    );
  }

  final raw = await file.readAsBytes();
  final out = await compute(_prepare, raw);
  if (out == null) {
    return const CoverPick.fail('Could not read that image. Try a JPG or PNG.');
  }
  if (out.length > _maxStoredBytes) {
    return const CoverPick.fail('That image is too detailed. Try another one.');
  }
  return CoverPick.ok(out);
}

// Runs in a background isolate so the UI doesn't freeze
Uint8List? _prepare(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final scale = min(1.0, min(600 / image.width, 900 / image.height));
  if (scale < 1.0) {
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 82));
}
