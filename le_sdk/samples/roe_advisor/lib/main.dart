/// Standalone entry point for the ROE Advisor extension.
library;

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

import 'roe_advisor_plugin.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final plugin = RoeAdvisorPlugin();
  plugin.onInitialize();
  plugin.onActivate();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: LatticeTheme.dark(),
    home: Builder(
      builder: (context) {
        final colors = context.lattice.colors;
        return Scaffold(
          appBar: AppBar(
            title: const Text('ROE Advisor — Preview'),
            backgroundColor: colors.background,
          ),
          body: SizedBox(
            width: 360,
            child: plugin.build(StubExtensionContext()),
          ),
        );
      },
    ),
  ));
}
