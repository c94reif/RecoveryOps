import 'package:ivy_pulse/presentation/common/display_mode.dart';

/// Non-web build: there is no browser to hand us a screen. Reports failure so
/// the caller can say so rather than flip a switch that did nothing.
Future<bool> enterFullScreen() async {
  fullScreenOn.value = false;
  return false;
}

Future<void> leaveFullScreen() async => fullScreenOn.value = false;
