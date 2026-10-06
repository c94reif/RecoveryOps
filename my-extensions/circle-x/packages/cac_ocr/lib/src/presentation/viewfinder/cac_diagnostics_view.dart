import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_diagnostics.dart';
import 'package:cac_ocr/src/presentation/cac_ocr_theme.dart';

class CacDiagnosticsView extends StatelessWidget {
  final CacScanDiagnostics diagnostics;
  final int recentFrames;

  const CacDiagnosticsView(
      {super.key, required this.diagnostics, this.recentFrames = 6});

  @override
  Widget build(BuildContext context) {
    final theme = CacOcrTheme.of(context);
    final style = TextStyle(
      color: theme.mutedText,
      fontSize: 10,
      fontFamily: 'monospace',
      height: 1.3,
    );
    return ListenableBuilder(
      listenable: diagnostics,
      builder: (context, _) {
        final reports = diagnostics.reports;
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 8),
          decoration: BoxDecoration(
            color: theme.raisedSurface,
            border: Border.all(color: theme.outline),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SCAN DIAGNOSTICS',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: reports.isEmpty
                        ? null
                        : () => Clipboard.setData(
                            ClipboardData(text: diagnostics.export())),
                    child: const Text('COPY LOG'),
                  ),
                ],
              ),
              Text(diagnostics.headline, style: style),
              for (final report
                  in reports.skip(math.max(0, reports.length - recentFrames)))
                Text(report.toLine(), style: style),
            ],
          ),
        );
      },
    );
  }
}
