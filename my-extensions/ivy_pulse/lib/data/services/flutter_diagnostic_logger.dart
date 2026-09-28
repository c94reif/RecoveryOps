import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/domain/services/diagnostic_logger.dart';

class FlutterDiagnosticLogger implements DiagnosticLogger {
  const FlutterDiagnosticLogger();

  @override
  void log(String message) => debugPrint(message);
}
