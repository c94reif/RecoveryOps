part of 'android_cac_scanner.dart';

mixin _CacLifecycle on _CacScannerState, WidgetsBindingObserver {
  @override
  void _watchLifecycle() => WidgetsBinding.instance.addObserver(this);

  @override
  void _unwatchLifecycle() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final completer = _inFlight;
    if (completer == null) return;
    switch (state) {
      // Inactive alone is a permission prompt or the notification shade,
      // with the scan still on screen.
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _pause();
      case AppLifecycleState.resumed:
        unawaited(_resume(completer));
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _pause() {
    if (_paused) return;
    _paused = true;
    _lifecycleRevision++;
    _timeout?.cancel();
    _timeout = null;
    final camera = _controller;
    _metering = null;
    preview.value = null;
    highlights.value = const [];
    final previous = _pausing;
    final focusing = _focusing;
    final processing = _processing;
    _pausing = () async {
      await previous;
      await focusing;
      await processing;
      await _disposeCamera(camera);
    }();
  }

  /// The side's time limit starts over on return.
  Future<void> _resume(Completer<CacCapture> completer) async {
    if (!_paused) return;
    _paused = false;
    final revision = ++_lifecycleRevision;
    // Whatever was opening or closing the camera settles first.
    await _pausing;
    await _startup;
    await _reopening;
    bool current() => _inFlight == completer && revision == _lifecycleRevision;
    final session = _session;
    if (!current() || session == null) return;
    // The reopened camera's focus starts the votes over.
    if (_controller == null) {
      final description = _description;
      final reopening = description == null
          ? Future<void>.error(StateError('no camera was chosen'))
          : _openAtOrBelow(description, _resolution, completer);
      _reopening = reopening.catchError((Object _) {});
      try {
        await reopening;
      } catch (error) {
        debugPrint('[CacOcr] camera did not come back: $error');
        if (current()) {
          _completeCapture(
              const CacCapture.failed(CacRejection.cameraTimedOut));
        }
        return;
      }
    }
    if (!current()) return;
    guidance.value = session.guidance;
    _startSideTimeout(completer, session);
  }
}
