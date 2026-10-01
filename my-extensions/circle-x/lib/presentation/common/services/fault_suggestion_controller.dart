import 'package:flutter/foundation.dart';
import 'package:circle_x/domain/repositories/reports_repo.dart';
import 'package:circle_x/presentation/common/services/snack_bar_service.dart';
import 'package:circle_x/domain/services/user_notification_sink.dart';

class FaultSuggestionController extends ChangeNotifier {
  final ReportsRepository repository;
  final UserNotificationSink notifications;
  final Set<String> dismissed = {};
  final Set<String> saving = {};
  bool loaded = false;
  bool loadFailed = false;
  bool _disposed = false;
  Future<void>? _loading;

  FaultSuggestionController(this.repository,
      {UserNotificationSink? notifications})
      : notifications = notifications ?? SnackBarService.instance;

  Future<void> load() {
    if (loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    try {
      final stored = await repository.getDismissedFaultSuggestions();
      if (_disposed) return;
      dismissed
        ..clear()
        ..addAll(stored);
      loaded = true;
      loadFailed = false;
    } catch (_) {
      loadFailed = true;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setDismissed(String id, bool value) async {
    if (!loaded || !saving.add(id)) return;
    notifyListeners();
    try {
      await repository.setFaultSuggestionDismissed(id, value);
      if (_disposed) return;
      value ? dismissed.add(id) : dismissed.remove(id);
    } catch (_) {
      if (!_disposed) {
        notifications.enqueue(
            'Could not save the suggestion preference. Try again.',
            isError: true);
      }
    } finally {
      saving.remove(id);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
