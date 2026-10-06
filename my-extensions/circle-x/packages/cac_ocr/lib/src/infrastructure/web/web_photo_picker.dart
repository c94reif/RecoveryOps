import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class WebPhotoPicker {
  static const Duration cancelGrace = Duration(seconds: 12);

  void Function(web.File?)? _completePending;

  int _generation = 0;

  void cancel() => _completePending?.call(null);

  Future<({web.File? photo, bool timedOut})> take({required Duration timeout}) {
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..accept = 'image/*'
      ..capture = 'environment';
    input.style.display = 'none';
    web.document.body?.appendChild(input);

    final completer = Completer<({web.File? photo, bool timedOut})>();
    final generation = ++_generation;
    Timer? cancelTimer;
    Timer? timeoutTimer;
    JSFunction? onFocus;
    var timedOut = false;
    DateTime? focusReturnedAt;

    void completePhotoCapture(web.File? file) {
      if (_generation == generation) _completePending = null;
      cancelTimer?.cancel();
      timeoutTimer?.cancel();
      if (onFocus != null) {
        web.window.removeEventListener('focus', onFocus);
        onFocus = null;
      }
      if (!completer.isCompleted) {
        completer.complete((photo: file, timedOut: timedOut));
      }
      input.remove();
    }

    _completePending = completePhotoCapture;

    input.onchange = (web.Event _) {
      final files = input.files;
      final photo = files != null && files.length > 0 ? files.item(0) : null;
      final since = focusReturnedAt;
      if (since != null) {
        final photoArrivalDelayMs =
            DateTime.now().difference(since).inMilliseconds;
        debugPrint(
            '[CacOcr] CAC photo arrived ${photoArrivalDelayMs}ms after focus '
            '(grace ${cancelGrace.inMilliseconds}ms)');
      }
      completePhotoCapture(photo);
    }.toJS;

    input.oncancel = ((web.Event _) => completePhotoCapture(null)).toJS;

    onFocus = ((web.Event _) {
      cancelTimer?.cancel();
      focusReturnedAt = DateTime.now();
      cancelTimer = Timer(cancelGrace, () {
        debugPrint('[CacOcr] CAC photo did not arrive within '
            '${cancelGrace.inMilliseconds}ms of focus — treating as cancelled');
        completePhotoCapture(null);
      });
    }).toJS;
    web.window.addEventListener('focus', onFocus);

    timeoutTimer = Timer(timeout, () {
      timedOut = true;
      completePhotoCapture(null);
    });

    input.click();
    return completer.future;
  }
}
