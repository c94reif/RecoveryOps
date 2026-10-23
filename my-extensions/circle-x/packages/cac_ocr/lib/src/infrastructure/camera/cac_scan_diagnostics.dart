import 'package:flutter/foundation.dart';
import 'package:cac_ocr/src/domain/cac_name.dart';
import 'package:cac_ocr/src/domain/cac_barcode.dart';
import 'package:cac_ocr/src/domain/cac_sides.dart';

enum CacFrameSkip { blur, glare }

@immutable
class CacFrameReport {
  final Duration at;
  final CacScanSide side;
  final double sharpness;
  final double sharpest;
  final double glare;

  final CacFrameSkip? skipped;
  final int linesKept;
  final int linesDropped;
  final double? lowestConfidence;
  final int doubtfulDigits;
  final List<CacBarcodeFormat> barcodes;

  final String? reading;
  final int backing;
  final bool contested;
  final Duration? readTime;

  const CacFrameReport({
    required this.at,
    required this.side,
    required this.sharpness,
    required this.sharpest,
    required this.glare,
    this.skipped,
    this.linesKept = 0,
    this.linesDropped = 0,
    this.lowestConfidence,
    this.doubtfulDigits = 0,
    this.barcodes = const [],
    this.reading,
    this.backing = 0,
    this.contested = false,
    this.readTime,
  });

  static String maskName(CacName name) =>
      '${_initial(name.lastName)}, ${_initial(name.firstName)}';

  static String maskDodId(String dodId) =>
      dodId.length <= 4 ? dodId : '••••••${dodId.substring(dodId.length - 4)}';

  static String _initial(String word) =>
      word.isEmpty ? '' : '${word[0]}${'•' * (word.length - 1)}';

  String toLine() => [
        '${(at.inMilliseconds / 1000).toStringAsFixed(2)}s',
        side.name,
        'sharp ${sharpness.toStringAsFixed(0)}/${sharpest.toStringAsFixed(0)}',
        'glare ${(glare * 100).toStringAsFixed(0)}%',
        if (skipped case final skip?) 'skipped ${skip.name}',
        if (skipped == null) ...[
          'lines $linesKept kept $linesDropped dropped',
          if (lowestConfidence != null)
            'conf ≥${lowestConfidence!.toStringAsFixed(2)}',
          if (doubtfulDigits > 0) 'doubtful digits $doubtfulDigits',
          if (barcodes.isNotEmpty) barcodes.map((b) => b.name).join('+'),
          if (reading != null)
            '$reading ($backing${contested ? ', contested' : ''})',
          if (readTime != null) '${readTime!.inMilliseconds}ms',
        ],
      ].join(' · ');
}

class CacScanDiagnostics extends ChangeNotifier {
  final int capacity;
  final _reports = <CacFrameReport>[];

  CacScanDiagnostics({this.capacity = 300});

  List<CacFrameReport> get reports => List.unmodifiable(_reports);
  CacFrameReport? get latest => _reports.lastOrNull;

  void add(CacFrameReport report) {
    _reports.add(report);
    if (_reports.length > capacity) _reports.removeAt(0);
    notifyListeners();
  }

  void clear() {
    _reports.clear();
    notifyListeners();
  }

  ({
    int frames,
    int blurred,
    int glary,
    int read,
    double? medianSharpness,
    double? medianConfidence,
  }) get summary => (
        frames: _reports.length,
        blurred: _reports.where((r) => r.skipped == CacFrameSkip.blur).length,
        glary: _reports.where((r) => r.skipped == CacFrameSkip.glare).length,
        read: _reports.where((r) => r.reading != null).length,
        medianSharpness: _median([for (final r in _reports) r.sharpness]),
        medianConfidence: _median([
          for (final r in _reports)
            if (r.lowestConfidence case final confidence?) confidence,
        ]),
      );

  String get headline {
    final total = summary;
    return [
      '${total.frames} frames',
      '${total.read} read',
      '${total.blurred} blurred',
      '${total.glary} glary',
      if (total.medianSharpness case final sharpness?)
        'median sharpness ${sharpness.toStringAsFixed(0)}',
      if (total.medianConfidence case final confidence?)
        'median confidence ${confidence.toStringAsFixed(2)}',
    ].join(' · ');
  }

  String export() => [
        'cac_ocr scan log · $headline',
        for (final report in _reports) report.toLine(),
      ].join('\n');

  static double? _median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
