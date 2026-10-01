import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';
import 'package:circle_x/core/theme/app_theme.dart';

import 'circle_x_extension.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final extensionContext = await ExtensionContext.connect();

  runApp(MaterialApp(
    title: 'circle-x',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    home: CircleXExtension().build(extensionContext),
  ));
}
