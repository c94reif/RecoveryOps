import 'package:ivy_pulse/presentation/common/unavailable_fullscreen.dart'
    if (dart.library.js_interop) 'package:ivy_pulse/presentation/common/web_fullscreen.dart'
    as platform;

/// Hand the extension the whole device screen.
///
/// The host's own panel-size API is a dead end for a web extension on host
/// 0.9.0 — its injected bridge exposes no `ui.setPanelSize`. The browser
/// Fullscreen API is not: `flutter_inappwebview`'s `onShowCustomView` handles
/// it natively, with no host Dart involvement, the same way the file-chooser
/// camera path works. Going fullscreen covers the Lattice status bar, the map
/// and the nav rail — every pixel is ours.
///
/// Needs transient user activation, so it can only ever run off a real tap;
/// there is no calling this on open.
Future<bool> enterFullScreen() => platform.enterFullScreen();

/// Give the screen back to the host.
Future<void> leaveFullScreen() => platform.leaveFullScreen();
