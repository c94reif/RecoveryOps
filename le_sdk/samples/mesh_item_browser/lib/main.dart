/// Standalone entry point for the Mesh Item Browser extension.
///
/// Run standalone:
///   flutter run -d chrome --web-browser-flag --disable-web-security
///
/// For production, bundled into the host app via the Lattice Edge extension
/// loader which loads this extension's compiled web assets.
library;

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

import 'mesh_item_browser_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final context = await ExtensionContext.connect();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: LatticeTheme.dark(),
    home: Scaffold(
      body: MeshItemBrowserPlugin().build(context),
    ),
  ));
}
