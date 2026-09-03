/// Standalone entry point for the Chat plugin.
///
/// Dart mode (native):
///   flutter run -d [device]
///   Renders the Dart plugin widget directly for testing.
///
/// For production, the Dart version is compiled into the host app via:
///   `import 'package:chat/chat_plugin.dart';`
library;

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

import 'chat_plugin.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final plugin = ChatPlugin();
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
            title: const Text('Chat — Preview'),
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
