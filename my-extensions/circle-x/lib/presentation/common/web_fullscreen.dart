import 'dart:js_interop';

import 'package:circle_x/presentation/common/display_mode.dart';
import 'package:web/web.dart' as web;

bool watching = false;

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
  } catch (_) {}
  fullScreenOn.value = web.document.fullscreenElement != null;
}
