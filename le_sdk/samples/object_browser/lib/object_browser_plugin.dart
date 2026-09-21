import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

import 'screens/browse_tab.dart';
import 'screens/upload_tab.dart';

class ObjectBrowserPlugin extends LatticeEdgeExtension {
  @override
  String get id => 'object_browser';

  @override
  String get name => 'Object Browser';

  @override
  String get description =>
      'Browse, upload, and manage objects in the Lattice CDN';

  @override
  IconData get icon => Icons.cloud_upload;

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) => _ObjectBrowserShell(context);
}

class _ObjectBrowserShell extends StatefulWidget {
  const _ObjectBrowserShell(this.context);
  final ExtensionContext context;

  @override
  State<_ObjectBrowserShell> createState() => _ObjectBrowserShellState();
}

class _ObjectBrowserShellState extends State<_ObjectBrowserShell>
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
    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          Container(
            color: colors.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: colors.accent,
              labelColor: colors.textPrimary,
              unselectedLabelColor: colors.textMuted,
              tabs: const [
                Tab(text: 'BROWSE'),
                Tab(text: 'UPLOAD'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                BrowseTab(context: widget.context),
                UploadTab(context: widget.context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
