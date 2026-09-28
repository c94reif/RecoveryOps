import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/domain/entities/cac_scan.dart';
import 'package:ivy_pulse/domain/services/cac_scanner_strategy.dart';
import 'package:ivy_pulse/domain/usecases/identity/verify_operator_identity.dart';

class CacScanController extends ChangeNotifier {
  final CacScannerStrategy cacScanner;
  final VerifyOperatorIdentity verifyOperatorIdentity;
  CacScan? lastScan;
  bool isScanning = false;
  int scanAttempts = 0;
  int scanGeneration = 0;
  bool _disposed = false;

  CacScanController(
      {required this.cacScanner, required this.verifyOperatorIdentity});

  Future<void> scan() async {
    if (isScanning || _disposed) return;

    final generation = ++scanGeneration;
    isScanning = true;
    scanAttempts++;
    lastScan = null;
    notifyListeners();

    CacScan outcome;
    try {
      outcome = await verifyOperatorIdentity();
      debugPrint('[IvyPulse] scanCac — attempt $scanAttempts, '
          '${outcome.isVerified ? 'verified' : outcome.rejection!.name}');
    } catch (error) {
      debugPrint('[IvyPulse] scanCac failed: $error');
      outcome = const CacScan.rejected(CacRejection.noCodeFound);
    }

    if (_disposed || generation != scanGeneration) {
      debugPrint('[IvyPulse] scanCac — result for abandoned scan, dropped');
      return;
    }

    lastScan = outcome;
    if (outcome.isVerified) {
      scanAttempts = 0;
    } else if (outcome.rejection == CacRejection.cameraTimedOut) {
      untallyAttempt();
    }
    isScanning = false;
    notifyListeners();
  }

  void untallyAttempt() {
    if (scanAttempts > 0) scanAttempts--;
  }

  void cancelScan() {
    if (!isScanning) return;

    scanGeneration++;
    isScanning = false;
    untallyAttempt();
    lastScan = const CacScan.rejected(CacRejection.cancelled);
    notifyListeners();

    cacScanner.cancel().catchError((Object error) {
      debugPrint('[IvyPulse] cancelScan — scanner refused the cancel: $error');
    });
  }

  void reset() {
    lastScan = null;
    isScanning = false;
    scanAttempts = 0;
    scanGeneration++;
  }

  @override
  void dispose() {
    _disposed = true;
    scanGeneration++;
    if (isScanning) {
      unawaited(cacScanner.cancel().catchError((Object error) {
        debugPrint('[IvyPulse] scan disposal failed: $error');
      }));
    }
    super.dispose();
  }
}
