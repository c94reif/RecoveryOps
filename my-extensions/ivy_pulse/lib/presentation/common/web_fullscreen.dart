import 'dart:js_interop';

import 'package:ivy_pulse/presentation/common/display_mode.dart';
import 'package:web/web.dart' as web;

bool watching = false;

/// The operator can leave fullscreen without touching our button — the system
/// back gesture does it — so follow the document rather than trusting our own
/// last write.
void watchFullScreenChanges() {
  if (watching) return;
  watching = true;
  web.document.onfullscreenchange = ((web.Event _) {
    fullScreenOn.value = web.document.fullscreenElement != null;
  }).toJS;
}

Future<bool> enterFullScreen() async {
  final root = web.document.documentElement;
  if (root == null) return false;
  watchFullScreenChanges();
  try {
    await root.requestFullscreen().toDart;
    fullScreenOn.value = web.document.fullscreenElement != null;
    return fullScreenOn.value;
  } catch (_) {
    // Throws when the tap that got us here no longer counts as user
    // activation, and on any host that blocks fullscreen outright.
    fullScreenOn.value = false;
    return false;
  }
}

Future<void> leaveFullScreen() async {
  if (web.document.fullscreenElement == null) {
    fullScreenOn.value = false;
    return;
  }
  try {
    await web.document.exitFullscreen().toDart;
  } catch (_) {
    // Nothing to do — the change listener holds the truth either way.
  }
  fullScreenOn.value = web.document.fullscreenElement != null;
}
