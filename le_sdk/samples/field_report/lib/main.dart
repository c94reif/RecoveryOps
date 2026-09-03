/// Standalone entry point for the Field Report extension.
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
///   `import 'package:field_report/field_report_plugin.dart';`
library;

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

import 'field_report_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final context = await ExtensionContext.connect();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: LatticeTheme.dark(),
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Field Report — Preview'),
      ),
      body: FieldReportPlugin().build(context),
    ),
  ));
}
