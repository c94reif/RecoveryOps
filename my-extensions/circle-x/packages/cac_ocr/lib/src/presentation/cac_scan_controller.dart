import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cac_ocr/src/domain/cac_rejection.dart';
import 'package:cac_ocr/src/domain/cac_scan.dart';
import 'package:cac_ocr/src/application/cac_scanner_strategy.dart';
import 'package:cac_ocr/src/application/verify_operator_identity.dart';

class CacScanController extends ChangeNotifier {
  final CacScannerStrategy cacScanner;
  final VerifyOperatorIdentity verifyOperatorIdentity;
  CacScan? _lastScan;
  bool _isScanning = false;
  int _scanAttempts = 0;
  int _generation = 0;
  bool _disposed = false;

  CacScanController(
      {required this.cacScanner, required this.verifyOperatorIdentity});

  CacScan? get lastScan => _lastScan;
  bool get isScanning => _isScanning;

  int get scanAttempts => _scanAttempts;

  Future<void> scan() async {
    if (_isScanning || _disposed) return;

    final generation = ++_generation;
    _isScanning = true;
    _scanAttempts++;
    _lastScan = null;
    notifyListeners();

    CacScan outcome;
    try {
      outcome = await verifyOperatorIdentity();
      debugPrint('[CacOcr] scanCac — attempt $_scanAttempts, '
          '${outcome.isVerified ? 'verified' : outcome.rejection!.name}');
    } catch (error) {
      debugPrint('[CacOcr] scanCac failed: $error');
      outcome = const CacScan.rejected(CacRejection.noCodeFound);
    }

    if (_disposed || generation != _generation) {
      debugPrint('[CacOcr] scanCac — result for abandoned scan, dropped');
      return;
    }

    _lastScan = outcome;
    if (outcome.isVerified) {
      _scanAttempts = 0;
    } else if (outcome.rejection == CacRejection.cameraTimedOut) {
      untallyAttempt();
    }
    _isScanning = false;
    notifyListeners();
  }

  void untallyAttempt() {
    if (_scanAttempts > 0) _scanAttempts--;
  }

  void cancelScan() {
    if (!_isScanning) return;

    _generation++;
    _isScanning = false;
    untallyAttempt();
    _lastScan = const CacScan.rejected(CacRejection.cancelled);
    notifyListeners();

    cacScanner.cancel().catchError((Object error) {
      debugPrint('[CacOcr] cancelScan — scanner refused the cancel: $error');
    });
  }

  void reset() {
    _lastScan = null;
    _isScanning = false;
    _scanAttempts = 0;
    _generation++;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    if (_isScanning) {
      unawaited(cacScanner.cancel().catchError((Object error) {
        debugPrint('[CacOcr] scan disposal failed: $error');
      }));
    }
    super.dispose();
  }
}
