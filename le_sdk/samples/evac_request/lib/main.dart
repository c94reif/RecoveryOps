/// Standalone entry point for the Call for Evac extension.
///
/// Dart mode (native):
///   flutter run -d [device]
///   Renders the Dart extension widget directly for testing.
///
/// Web mode:
///   Build web/index.html and host it at any URL, then register
///   that URL in the Lattice host app via Settings > Register Web Extension.
///
/// For production, the Dart version is compiled into the host app via:
///   `import 'package:evac_request/evac_request_plugin.dart';`
library;

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

import 'evac_request_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final context = await ExtensionContext.connect();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: LatticeTheme.dark(),
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Call for Evac — Preview'),
      ),
      body: EvacRequestPlugin().build(context),
    ),
  ));
}
