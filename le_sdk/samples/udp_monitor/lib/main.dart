/// Standalone entry point for the UDP Monitor extension.
///
/// Web mode (real host services):
///   Deploy with le_sdk/scripts/deploy-extension.sh and open from the host
///   app's extension grid. `context.network` is backed by the host's
///   HostNetworkService (real UDP sockets).
///
/// Standalone preview (`flutter run -d chrome`):
///   `ExtensionContext.connect()` returns a StubExtensionContext whose
///   network service is a no-op — subscribe resolves to an empty stream and
///   sends report `error: 'stub'`. Use this only to iterate on the UI.
library;

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

import 'udp_monitor_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final context = await ExtensionContext.connect();

  // Scaffold (no AppBar): the host already draws the panel chrome (title bar,
  // close button), so a wrapper AppBar would double up inside the host. The
  // Scaffold is still needed to provide a Material ancestor + default text
  // styling for the plugin's own widgets.
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: LatticeTheme.dark(),
    home: Scaffold(body: UdpMonitorPlugin().build(context)),
  ));
}
