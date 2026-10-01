import 'package:circle_x/presentation/common/display_mode.dart';

Future<bool> enterFullScreen() async {
  fullScreenOn.value = false;
  return false;
}

Future<void> leaveFullScreen() async => fullScreenOn.value = false;
