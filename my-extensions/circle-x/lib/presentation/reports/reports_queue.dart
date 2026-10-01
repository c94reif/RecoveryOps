part of 'reports_view_model.dart';

/// Coalesced queue refreshes and pending submission counts.
mixin _ReportsQueue on _ReportsState {
  @override
  Future<void> refreshQueued() {
    if (queueRefreshInFlight != null) {
      queueRefreshAgain = true;
      return queueRefreshInFlight!;
    }
    return queueRefreshInFlight = refreshQueueUntilCurrent().whenComplete(() {
      queueRefreshInFlight = null;
    });
  }

  Future<void> refreshQueueUntilCurrent() async {
    do {
      queueRefreshAgain = false;
      try {
        final parked = await queuedRepository.getAll();
        if (disposed) return;
        queued
          ..clear()
          ..addAll(parked.reversed);
        await refreshQueuedCount();
        if (disposed) return;
        notifyListeners();
      } catch (error) {
        debugPrint('[CircleX] refreshQueued error: $error');
      }
    } while (queueRefreshAgain && !disposed);
  }

  @override
  Future<void> refreshQueuedCount() async {
    try {
      final count = await queueWorker.pendingCount();
      if (!disposed) queuedCount.value = count;
    } catch (error) {
      debugPrint('[CircleX] refreshQueuedCount error: $error');
    }
  }
}
