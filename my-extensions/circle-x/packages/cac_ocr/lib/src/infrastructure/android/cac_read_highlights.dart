import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cac_ocr/src/domain/cac_name.dart';
import 'package:cac_ocr/src/infrastructure/android/cac_frame_text.dart';

List<Rect> cacReadHighlights({
  required CacName? name,
  required String? dodId,
  required CacFrameText text,
  required List<Rect> barcodeBoxes,
  required InputImageMetadata metadata,
}) {
  final sideways = metadata.rotation == InputImageRotation.rotation90deg ||
      metadata.rotation == InputImageRotation.rotation270deg;
  final crop = metadata.size;
  final upright = sideways ? Size(crop.height, crop.width) : crop;
  final surname = name?.lastName.toUpperCase();
  bool holdsReading(String line) =>
      (surname != null && line.toUpperCase().contains(surname)) ||
      (dodId != null && line.replaceAll(RegExp(r'\D'), '').contains(dodId));
  return [
    for (final box in barcodeBoxes) _within(box, upright),
    for (var index = 0; index < text.lines.length; index++)
      if (holdsReading(text.lines[index])) _within(text.boxes[index], upright),
  ];
}

Rect _within(Rect box, Size image) => Rect.fromLTRB(
      (box.left / image.width).clamp(0.0, 1.0),
      (box.top / image.height).clamp(0.0, 1.0),
      (box.right / image.width).clamp(0.0, 1.0),
      (box.bottom / image.height).clamp(0.0, 1.0),
    );
