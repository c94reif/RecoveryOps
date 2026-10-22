part of 'reports_view_model.dart';

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

  Future<void> sendQueuedNow(QueuedSubmission submission) async {
    final id = submission.id;
    if (id == null || !sendingNow.add(id)) return;
    notifyListeners();
    var delivered = false;
    try {
      delivered = await queueWorker.sendNow(submission);
    } catch (error) {
      debugPrint('[CircleX] Manual send failed: $error');
    }
    if (disposed) return;
    sendingNow.remove(id);
    final transport = submission.transport.displayName;
    snackBarService.enqueue(
      delivered
          ? 'Sent over $transport — ${submission.summary}'
          : '$transport still unreachable — will keep retrying',
      isError: !delivered,
    );
    notifyListeners();
    await refreshQueued();
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
