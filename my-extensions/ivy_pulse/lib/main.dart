import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';

import 'ivy_pulse_extension.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final extensionContext = await ExtensionContext.connect();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    home: IvyPulseExtension().build(extensionContext),
  ));
}
