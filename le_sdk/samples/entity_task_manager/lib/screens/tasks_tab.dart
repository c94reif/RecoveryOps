import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

import '../widgets/style.dart';

enum _TasksView { list, create, detail }

class TasksTab extends StatefulWidget {
  final ExtensionContext context;

  const TasksTab({super.key, required this.context});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  List<TaskData> _tasks = [];
  bool _loading = false;
  String? _statusMessage;
  TaskStatusGroup? _filterGroup;
  _TasksView _view = _TasksView.list;
  TaskData? _selectedTask;

  // Create form state
  final _descriptionController = TextEditingController();
  final _specTypeController =
      TextEditingController(text: 'type.googleapis.com/sample.Task');
  String? _assigneeEntityId;
  bool _creating = false;
  List<Entity> _availableEntities = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _specTypeController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final tasks = await widget.context.tasks.queryTasks(
        statusGroups: _filterGroup != null ? [_filterGroup!] : null,
      );
      if (mounted) setState(() => _tasks = tasks);
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToList() {
    setState(() {
      _view = _TasksView.list;
      _selectedTask = null;
    });
  }

  void _goToCreate() {
    _descriptionController.clear();
    _specTypeController.text = 'type.googleapis.com/sample.Task';
    _assigneeEntityId = null;
    _creating = false;
    _availableEntities = [];
    setState(() => _view = _TasksView.create);
    _loadEntities();
  }

  void _goToDetail(TaskData task) {
    setState(() {
      _view = _TasksView.detail;
      _selectedTask = task;
    });
  }

  Future<void> _loadEntities() async {
    try {
      final entities = await widget.context.entities.getEntities();
      if (mounted) setState(() => _availableEntities = entities);
    } catch (_) {}
  }

  Future<void> _doCreate() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) return;

    setState(() => _creating = true);
    try {
      final task = await widget.context.tasks.createTask(
        CreateTaskParams(
          specificationTypeUrl: _specTypeController.text.trim(),
          specificationBytes: utf8.encode(description),
          description: description,
          assigneeEntityId: _assigneeEntityId,
        ),
      );
      if (mounted) {
        _descriptionController.clear();
        _specTypeController.text = 'type.googleapis.com/sample.Task';
        _assigneeEntityId = null;
        _creating = false;
        _statusMessage = 'Created task: ${task.taskId}';
        await _refresh();
        _goToList();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _statusMessage = 'Create failed: $e';
        });
      }
    }
  }

  Color _statusGroupColor(TaskStatusGroup group) {
    return switch (group) {
      TaskStatusGroup.pending => const Color(0xFFFFEB3B),
      TaskStatusGroup.active => const Color(0xFF4A90D9),
      TaskStatusGroup.terminal => const Color(0xFF888888),
    };
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      _TasksView.list => _buildListView(),
      _TasksView.create => _buildCreateView(),
      _TasksView.detail => _buildDetailView(),
    };
  }

  // ---------------------------------------------------------------------------
  // List view
  // ---------------------------------------------------------------------------

  Widget _buildListView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _goToCreate,
                    icon: Icon(Icons.add, size: 18, color: context.lattice.colors.onAccent),
                    label: Text('Create',
                        style: TextStyle(
                            color: context.lattice.colors.onAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    style: LatticeStyle.primaryButtonFrom(context.lattice.colors),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                width: 48,
                child: IconButton(
                  onPressed: _refresh,
                  icon: Icon(Icons.refresh,
                      size: 20, color: LatticeStyle.textSecondary),
                  style: IconButton.styleFrom(
                    backgroundColor: LatticeStyle.surface,
                    side: BorderSide(color: LatticeStyle.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              _filterChip(null, 'ALL'),
              const SizedBox(width: 6),
              _filterChip(TaskStatusGroup.pending, 'PENDING'),
              const SizedBox(width: 6),
              _filterChip(TaskStatusGroup.active, 'ACTIVE'),
              const SizedBox(width: 6),
              _filterChip(TaskStatusGroup.terminal, 'DONE'),
            ],
          ),
        ),
        if (_statusMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(_statusMessage!,
                style: TextStyle(
                    color: _statusMessage!.startsWith('Error') ||
                            _statusMessage!.startsWith('Create failed')
                        ? LatticeStyle.error
                        : LatticeStyle.success,
                    fontSize: 11)),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(color: context.lattice.colors.accent))
              : _tasks.isEmpty
                  ? Center(
                      child: Text('No tasks',
                          style: TextStyle(
                              color: LatticeStyle.textMuted, fontSize: 13)))
                  : ClipRect(
                      child: ListView.separated(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (ctx, i) => _buildTaskTile(_tasks[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(TaskStatusGroup? group, String label) {
    final selected = _filterGroup == group;
    return GestureDetector(
      onTap: () {
        setState(() => _filterGroup = group);
        _refresh();
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? context.lattice.colors.accent.withValues(alpha: 0.15)
              : LatticeStyle.background,
          border: Border.all(
            color: selected ? context.lattice.colors.accent : LatticeStyle.border,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color:
                  selected ? context.lattice.colors.accent : LatticeStyle.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskTile(TaskData task) {
    return GestureDetector(
      onTap: () => _goToDetail(task),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LatticeStyle.surface,
          border: Border.all(color: LatticeStyle.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _statusGroupColor(task.statusGroup),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.description.isNotEmpty
                        ? task.description
                        : task.taskId,
                    style: TextStyle(
                        color: LatticeStyle.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.statusLabel} \u2022 ${_timeAgo(task.lastUpdateTime)}',
                    style: TextStyle(
                        color: LatticeStyle.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    _statusGroupColor(task.statusGroup).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                task.statusGroup.name.toUpperCase(),
                style: TextStyle(
                  color: _statusGroupColor(task.statusGroup),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Create view (inline form)
  // ---------------------------------------------------------------------------

  Widget _buildCreateView() {
    return Column(
      children: [
        _inlineHeader('Create Task', onBack: _goToList),
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _descriptionController,
                    autofocus: true,
                    style: TextStyle(
                        color: LatticeStyle.textPrimary, fontSize: 13),
                    maxLines: 3,
                    minLines: 2,
                    decoration: LatticeStyle.inputDecoration('Task description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _specTypeController,
                    style: TextStyle(
                        color: LatticeStyle.textPrimary, fontSize: 13),
                    decoration:
                        LatticeStyle.inputDecoration('Specification type URL'),
                  ),
                  const SizedBox(height: 12),
                  Text('ASSIGN TO',
                      style: TextStyle(
                          color: LatticeStyle.sectionLabel,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  if (_availableEntities.isEmpty)
                    Text('No entities available',
                        style: TextStyle(
                            color: LatticeStyle.textMuted, fontSize: 11))
                  else
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: LatticeStyle.background,
                        border: Border.all(color: LatticeStyle.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String?>(
                        value: _assigneeEntityId,
                        isExpanded: true,
                        dropdownColor: LatticeStyle.surface,
                        underline: const SizedBox(),
                        hint: Text('Unassigned',
                            style: TextStyle(
                                color: LatticeStyle.textMuted, fontSize: 12)),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Unassigned',
                                style: TextStyle(
                                    color: LatticeStyle.textSecondary,
                                    fontSize: 12)),
                          ),
                          ..._availableEntities.map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.name,
                                    style: TextStyle(
                                        color: LatticeStyle.textPrimary,
                                        fontSize: 12)),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _assigneeEntityId = v),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _goToList,
                            style: LatticeStyle.secondaryButtonFrom(context.lattice.colors),
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: LatticeStyle.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _creating ? null : _doCreate,
                            style: LatticeStyle.primaryButtonFrom(context.lattice.colors),
                            child: _creating
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: context.lattice.colors.onAccent))
                                : Text('Create',
                                    style: TextStyle(
                                        color: context.lattice.colors.onAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Detail view (inline)
  // ---------------------------------------------------------------------------

  Widget _buildDetailView() {
    final task = _selectedTask;
    if (task == null) return const SizedBox.shrink();

    return Column(
      children: [
        _inlineHeader('Task Detail', onBack: _goToList),
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.description.isNotEmpty
                        ? task.description
                        : task.taskId,
                    style: TextStyle(
                        color: LatticeStyle.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _detailRow('Task ID', task.taskId),
                  _detailRow('Status',
                      '${task.statusLabel} (${task.statusGroup.name})'),
                  _detailRow('Spec Type', task.specificationTypeUrl),
                  if (task.assigneeEntityId != null)
                    _detailRow('Assignee', task.assigneeEntityId!),
                  if (task.parentTaskId != null)
                    _detailRow('Parent Task', task.parentTaskId!),
                  if (task.errorMessage != null)
                    _detailRow('Error', task.errorMessage!),
                  _detailRow('Created',
                      '${task.createTime.hour.toString().padLeft(2, '0')}:${task.createTime.minute.toString().padLeft(2, '0')}'),
                  _detailRow('Updated',
                      '${task.lastUpdateTime.hour.toString().padLeft(2, '0')}:${task.lastUpdateTime.minute.toString().padLeft(2, '0')}'),
                  if (task.initialEntities.isNotEmpty)
                    _detailRow(
                        'Entities',
                        task.initialEntities
                            .map((e) => e.displayName ?? e.entityId)
                            .join(', ')),
                  const SizedBox(height: 12),
                  if (task.statusGroup != TaskStatusGroup.terminal) ...[
                    Row(
                      children: [
                        if (task.statusGroup == TaskStatusGroup.pending)
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await widget.context.tasks
                                      .updateStatus(task.taskId, 2);
                                  _refresh();
                                  _goToList();
                                },
                                style: LatticeStyle.primaryButtonFrom(context.lattice.colors),
                                child: Text('Start',
                                    style: TextStyle(
                                        color: context.lattice.colors.onAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        if (task.statusGroup == TaskStatusGroup.active)
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await widget.context.tasks
                                      .updateStatus(task.taskId, 8);
                                  _refresh();
                                  _goToList();
                                },
                                style: LatticeStyle.primaryButtonFrom(context.lattice.colors),
                                child: Text('Complete',
                                    style: TextStyle(
                                        color: context.lattice.colors.onAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () async {
                                await widget.context.tasks.cancelTask(
                                    task.taskId,
                                    reason: 'Cancelled by user');
                                _refresh();
                                _goToList();
                              },
                              style: LatticeStyle.secondaryButtonFrom(context.lattice.colors),
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: LatticeStyle.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

  Widget _inlineHeader(String title, {required VoidCallback onBack}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LatticeStyle.borderLight),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back,
                  size: 18, color: LatticeStyle.textSecondary),
            ),
          ),
          Text(title,
              style: TextStyle(
                  color: LatticeStyle.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    color: LatticeStyle.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: LatticeStyle.textPrimary, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
