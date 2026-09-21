import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

import 'object_browser_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final context = await ExtensionContext.connect();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: LatticeTheme.dark(),
    home: ObjectBrowserPlugin().build(context),
  ));
}
