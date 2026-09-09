import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

import 'ivy_pulse_extension.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final extensionContext = await ExtensionContext.connect();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
    ),
    home: Scaffold(
      appBar: AppBar(
        title: const Text(
            'Lattice Edge App to aid Soldiers in properly PMCSing — Preview'),
        backgroundColor: const Color(0xFF0A0A0A),
      ),
      body: IvyPulseExtension().build(extensionContext),
    ),
  ));
}
