import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

class IvyPulseExtension extends LatticeEdgeExtension {
  @override
  String get id => 'ivy_pulse';

  @override
  String get name => 'Lattice Edge App to aid Soldiers in properly PMCSing';

  @override
  String get description => 'A Lattice Edge extension';

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext extensionContext) =>
      IvyPulseExtensionUI(extensionContext: extensionContext);
}

class IvyPulseExtensionUI extends StatefulWidget {
  final ExtensionContext extensionContext;
  const IvyPulseExtensionUI({super.key, required this.extensionContext});

  @override
  State<IvyPulseExtensionUI> createState() => _IvyPulseExtensionUIState();
}

class _IvyPulseExtensionUIState extends State<IvyPulseExtensionUI> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // TODO: Build your extension UI here
        const Text(
          'Lattice Edge App to aid Soldiers in properly PMCSing',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Edit lib/ivy_pulse_extension.dart to get started.',
          style: TextStyle(color: Color(0xFF888888), fontSize: 13),
        ),
      ],
    );
  }
}
