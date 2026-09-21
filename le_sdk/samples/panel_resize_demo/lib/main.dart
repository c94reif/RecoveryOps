/// Standalone entry point for the Panel Resize Demo extension.
library;

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

import 'panel_resize_demo_plugin.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final plugin = PanelResizeDemoPlugin();
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
            title: const Text('Panel Resize Demo — Preview'),
            backgroundColor: colors.background,
          ),
          // Standalone preview: no host, so setPanelSize is a no-op on the stub
          // context — drag the window narrower/wider to exercise the reflow.
          body: SizedBox(
            width: 360,
            child: plugin.build(StubExtensionContext()),
          ),
        );
      },
    ),
  ));
}
