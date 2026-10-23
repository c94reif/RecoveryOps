import 'package:flutter_test/flutter_test.dart';
import 'package:cac_ocr/src/domain/cac_barcode.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';
import 'package:cac_ocr/src/infrastructure/camera/cac_scan_diagnostics.dart';

void main() {
  CacFrameReport report({
    double sharpness = 120,
    CacFrameSkip? skipped,
    double? lowestConfidence,
    String? reading,
  }) =>
      CacFrameReport(
        at: const Duration(milliseconds: 1250),
        side: CacScanSide.back,
        sharpness: sharpness,
        sharpest: 150,
        glare: 0.04,
        skipped: skipped,
        lowestConfidence: lowestConfidence,
        reading: reading,
      );

  group('a frame report', () {
    test('masks a name to its initials and a DoD ID to its last four', () {
      expect(CacFrameReport.maskName((firstName: 'JOHN A', lastName: 'SMITH')),
          'S••••, J•••••');
      expect(CacFrameReport.maskName((firstName: '', lastName: 'LI')), 'L•, ');
      expect(CacFrameReport.maskDodId('1087987498'), '••••••7498');
      expect(CacFrameReport.maskDodId('7498'), '7498');
    });

    test('says why a frame was skipped, and nothing it did not measure', () {
      expect(report(skipped: CacFrameSkip.blur).toLine(),
          '1.25s · back · sharp 120/150 · glare 4% · skipped blur');
    });

    test('lays out a read frame', () {
      const read = CacFrameReport(
        at: Duration(milliseconds: 80),
        side: CacScanSide.back,
        sharpness: 98.6,
        sharpest: 98.6,
        glare: 0.2,
        linesKept: 3,
        linesDropped: 1,
        lowestConfidence: 0.814,
        doubtfulDigits: 1,
        barcodes: [CacBarcodeFormat.code39],
        reading: 'DoD ID ••••••7498',
        backing: 2,
        contested: true,
        readTime: Duration(milliseconds: 143),
      );

      expect(
          read.toLine(),
          '0.08s · back · sharp 99/99 · glare 20% · lines 3 kept 1 dropped · '
          'conf ≥0.81 · doubtful digits 1 · code39 · '
          'DoD ID ••••••7498 (2, contested) · 143ms');
    });
  });

  group('the log', () {
    test('keeps the latest frames up to its capacity', () {
      final log = CacScanDiagnostics(capacity: 2);
      var changes = 0;
      log.addListener(() => changes++);
      for (final sharpness in [1.0, 2.0, 3.0]) {
        log.add(report(sharpness: sharpness));
      }

      expect([for (final r in log.reports) r.sharpness], [2, 3]);
      expect(log.latest!.sharpness, 3);
      expect(changes, 3);
      log.clear();
      expect(log.reports, isEmpty);
      expect(log.latest, isNull);
      expect(changes, 4);
    });

    test('sums up what the frames were and where the medians sit', () {
      final log = CacScanDiagnostics()
        ..add(report(sharpness: 10, skipped: CacFrameSkip.blur))
        ..add(report(sharpness: 20, skipped: CacFrameSkip.glare))
        ..add(report(
            sharpness: 30, lowestConfidence: 0.9, reading: 'name S•, J•'))
        ..add(report(sharpness: 40, lowestConfidence: 0.7));

      final summary = log.summary;
      expect(summary.frames, 4);
      expect(summary.blurred, 1);
      expect(summary.glary, 1);
      expect(summary.read, 1);
      expect(summary.medianSharpness, 25);
      expect(summary.medianConfidence, closeTo(0.8, 1e-9));
      expect(
          log.headline,
          '4 frames · 1 read · 1 blurred · 1 glary · median sharpness 25 · '
          'median confidence 0.80');

      log.add(report(sharpness: 50));
      expect(log.summary.medianSharpness, 30);
    });

    test('exports a header and one line a frame, newest last', () {
      final empty = CacScanDiagnostics();
      expect(empty.summary.medianSharpness, isNull);
      expect(empty.export(),
          'cac_ocr scan log · 0 frames · 0 read · 0 blurred · 0 glary');

      final log = CacScanDiagnostics()
        ..add(report(skipped: CacFrameSkip.blur))
        ..add(report(sharpness: 90, skipped: CacFrameSkip.glare));
      expect(log.export().split('\n'), [
        'cac_ocr scan log · ${log.headline}',
        log.reports.first.toLine(),
        log.reports.last.toLine(),
      ]);
    });
  });
}
