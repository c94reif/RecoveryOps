import 'package:flutter/foundation.dart';
import 'package:circle_x/domain/services/diagnostic_logger.dart';

class FlutterDiagnosticLogger implements DiagnosticLogger {
  const FlutterDiagnosticLogger();

  @override
  void log(String message) => debugPrint(message);
}
