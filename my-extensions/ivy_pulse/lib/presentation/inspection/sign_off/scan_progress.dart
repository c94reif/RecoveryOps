import 'package:flutter/material.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';
import 'package:ivy_pulse/presentation/inspection/viewfinder/cac_viewfinder.dart';

class SignOffScanning extends StatelessWidget {
  final CacScannerStrategy scanner;
  final bool isBusy;
  final VoidCallback onCancel;

  const SignOffScanning({
    super.key,
    required this.scanner,
    required this.isBusy,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCacViewfinder(scanner) ??
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border, width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Reading the card — fill the frame with the back, the '
                      'side with the wide barcode strip.',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: minTouchTarget,
            child: TextButton(
              onPressed: isBusy ? null : onCancel,
              child: const Text('CANCEL SCAN'),
            ),
          ),
        ),
        const Text(
          'Camera frames are discarded after reading. Cancelling closes the '
          'camera and leaves the PMCS unsigned.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }
}
