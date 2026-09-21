/// Standalone entry point for the Entity & Task Manager extension.
///
/// Run standalone:
///   flutter run -d [device]
///
/// For production, compiled into the host app via:
///   `import 'package:entity_task_manager/entity_task_manager_plugin.dart';`
library;

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

import 'entity_task_manager_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final context = await ExtensionContext.connect();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: LatticeTheme.dark(),
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Entity & Task Manager — Preview'),
      ),
      body: EntityTaskManagerPlugin().build(context),
    ),
  ));
}
