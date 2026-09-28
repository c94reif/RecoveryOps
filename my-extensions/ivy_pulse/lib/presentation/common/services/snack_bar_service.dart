import 'package:flutter/foundation.dart';
import 'package:ivy_pulse/domain/services/user_notification_sink.dart';

class SnackBarData {
  final String message;
  final bool isError;
  final bool persistent;

  SnackBarData(
      {required this.message, this.isError = false, this.persistent = false});
}

class SnackBarService extends ChangeNotifier implements UserNotificationSink {
  static final SnackBarService instance = SnackBarService();

  SnackBarService();

  final List<SnackBarData> queue = [];

  @override
  void enqueue(String message,
      {bool isError = false, bool persistent = false}) {
    queue.add(SnackBarData(
        message: message, isError: isError, persistent: persistent));
    notifyListeners();
  }

  SnackBarData? dequeue() {
    if (queue.isEmpty) return null;
    return queue.removeAt(0);
  }

  bool get hasMessages => queue.isNotEmpty;
}
