/// CORS proxy test extension.
///
/// Fetches an external URL (Google DNS-over-HTTPS) and displays
/// the result. Without a proxy configured, the fetch fails with
/// a CORS error. With the proxy, it succeeds.
library;

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

import 'cors_test_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final context = await ExtensionContext.connect();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: LatticeTheme.dark(),
    home: Scaffold(
      body: CorsTestPlugin().build(context),
    ),
  ));
}
