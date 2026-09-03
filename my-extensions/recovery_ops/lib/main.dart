import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';
import 'package:recovery_ops/core/theme/appTheme.dart';

import 'recovery_ops_extension.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final extensionContext = await ExtensionContext.connect();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    home: RecoveryOpsExtension().build(extensionContext),
  ));
}
