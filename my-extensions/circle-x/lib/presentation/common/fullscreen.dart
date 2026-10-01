import 'package:circle_x/presentation/common/unavailable_fullscreen.dart'
    if (dart.library.js_interop) 'package:circle_x/presentation/common/web_fullscreen.dart'
    as platform;

Future<bool> enterFullScreen() => platform.enterFullScreen();

Future<void> leaveFullScreen() => platform.leaveFullScreen();
