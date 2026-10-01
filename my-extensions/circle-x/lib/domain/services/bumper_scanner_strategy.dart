abstract interface class BumperScannerStrategy {
  bool get isSupported;
  Future<void> start();
  Future<List<String>> read();
  Future<void> stop();
  Future<void> dispose();
}

enum BumperScanFailure implements Exception {
  unavailable,
  unreadable,
  timedOut,
  cancelled;

  String get message => switch (this) {
        unavailable => 'Camera unavailable. Check camera permission and try '
            'again, or cancel and type the bumper number.',
        unreadable => 'Could not read the markings. Move closer, hold steady, '
            'and tap Read markings again.',
        timedOut => 'The camera did not return readable text. Try again, or '
            'cancel and type the bumper number.',
        cancelled => 'Scan cancelled.',
      };
}
