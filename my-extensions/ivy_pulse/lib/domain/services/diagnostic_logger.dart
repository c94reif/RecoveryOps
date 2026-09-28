abstract interface class DiagnosticLogger {
  void log(String message);
}

class SilentDiagnosticLogger implements DiagnosticLogger {
  const SilentDiagnosticLogger();

  @override
  void log(String message) {}
}
