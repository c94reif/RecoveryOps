import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

import 'screens/items_tab.dart';
import 'screens/streams_tab.dart';

/// Sample extension demonstrating the MeshItemService and MeshStreamService APIs.
///
/// Two-tab panel:
/// - Items — discover data types, browse items, create/edit/delete
/// - Streams — discover stream types, live-tail, publish messages
class MeshItemBrowserPlugin extends LatticeEdgeExtension {
  @override
  String get id => 'mesh_item_browser';

  @override
  String get name => 'Mesh Item Browser';

  @override
  String get description => 'Browse and manage mesh-item-store items and streams';

  @override
  IconData get icon => Icons.storage;

  @override
  String? get iconAsset => 'assets/logo.png';

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) =>
      _MeshItemBrowserShell(context: context);
}

/// Persistent tab scaffold for the Mesh Item Browser extension.
class _MeshItemBrowserShell extends StatefulWidget {
  final ExtensionContext context;

  const _MeshItemBrowserShell({required this.context});

  @override
  State<_MeshItemBrowserShell> createState() => _MeshItemBrowserShellState();
}

class _MeshItemBrowserShellState extends State<_MeshItemBrowserShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: colors.accent,
          labelColor: colors.accent,
          unselectedLabelColor: colors.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          tabs: const [
            Tab(text: 'ITEMS'),
            Tab(text: 'STREAMS'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const ClampingScrollPhysics(),
            children: [
              ItemsTab(context: widget.context),
              StreamsTab(context: widget.context),
            ],
          ),
        ),
      ],
    );
  }
}
