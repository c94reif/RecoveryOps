import 'package:flutter/material.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_live_feedback.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_text.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';

class CacTorchButton extends StatelessWidget {
  final CacLiveFeedback live;
  final CacOcrText text;

  const CacTorchButton(
      {super.key, required this.live, this.text = const CacOcrText()});

  @override
  Widget build(BuildContext context) {
    final theme = CacOcrTheme.of(context);
    return ValueListenableBuilder<bool?>(
      valueListenable: live.torch,
      builder: (_, on, __) => on == null
          ? const SizedBox.shrink()
          : IconButton(
              tooltip: on ? text.torchOff : text.torchOn,
              isSelected: on,
              color: on ? theme.accent : Colors.white,
              style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.45)),
              icon: Icon(on ? Icons.flashlight_on : Icons.flashlight_off),
              onPressed: () => live.setTorch(!on),
            ),
    );
  }
}
