/// Standalone entry point for the CASEVAC 9-Line extension.
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
///   `import 'package:casevac_report/casevac_report_plugin.dart';`
library;

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

import 'casevac_report_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final context = await ExtensionContext.connect();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: LatticeTheme.dark(),
    home: Scaffold(
      appBar: AppBar(
        title: const Text('CASEVAC 9-Line — Preview'),
      ),
      body: CasevacReportPlugin().build(context),
    ),
  ));
}
