import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

import 'screens/entities_tab.dart';
import 'screens/tasks_tab.dart';

/// Sample extension demonstrating the EntityService and TaskService APIs.
class EntityTaskManagerPlugin extends LatticeEdgeExtension {
  @override
  String get id => 'entity_task_manager';

  @override
  String get name => 'Entity & Task Manager';

  @override
  String get description => 'Create and manage entities and tasks';

  @override
  IconData get icon => Icons.hub;

  @override
  String? get iconAsset => 'assets/logo.png';

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) => _ManagerHome(context: context);
}

class _ManagerHome extends StatefulWidget {
  final ExtensionContext context;

  const _ManagerHome({required this.context});

  @override
  State<_ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<_ManagerHome>
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
            Tab(text: 'ENTITIES'),
            Tab(text: 'TASKS'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const ClampingScrollPhysics(),
            children: [
              EntitiesTab(context: widget.context),
              TasksTab(context: widget.context),
            ],
          ),
        ),
      ],
    );
  }
}
