import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

import '../widgets/style.dart';

enum _EntitiesView { list, create, detail, search }

class EntitiesTab extends StatefulWidget {
  final ExtensionContext context;

  const EntitiesTab({super.key, required this.context});

  @override
  State<EntitiesTab> createState() => _EntitiesTabState();
}

class _EntitiesTabState extends State<EntitiesTab> {
  List<Entity> _entities = [];
  bool _loading = false;
  String? _statusMessage;
  _EntitiesView _view = _EntitiesView.list;
  Entity? _selectedEntity;

  // Create form state
  final _nameController = TextEditingController();
  Disposition _disposition = Disposition.friendly;
  LatLng? _location;
  bool _creating = false;

  // Search state
  final _searchController = TextEditingController();
  bool _searching = false;

  // Entity stream
  StreamSubscription<EntityEvent>? _streamSub;

  @override
  void initState() {
    super.initState();
    _refresh();
    _listenToStream();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToStream() {
    _streamSub = widget.context.entities.streamEntityComponents().listen(
      (event) {
        if (!mounted) return;
        setState(() {
          switch (event) {
            case EntityUpsert(:final entity):
              final idx = _entities.indexWhere((e) => e.id == entity.id);
              if (idx >= 0) {
                _entities[idx] = entity;
              } else {
                _entities.add(entity);
              }
            case EntityDelete(:final entityId):
              _entities.removeWhere((e) => e.id == entityId);
          }
        });
      },
      onError: (e) {
        debugPrint('[EntityTaskManager] Entity stream error: $e');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Data operations
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final entities = await widget.context.entities.getEntities();
      if (mounted) setState(() => _entities = entities);
    } catch (e) {
      debugPrint('[EntityTaskManager] getEntities error: $e');
      if (mounted) setState(() => _statusMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToList() {
    setState(() {
      _view = _EntitiesView.list;
      _selectedEntity = null;
    });
  }

  void _goToCreate() {
    _nameController.clear();
    _disposition = Disposition.friendly;
    _location = null;
    _creating = false;
    setState(() => _view = _EntitiesView.create);
  }

  void _goToSearch() {
    _searchController.clear();
    _searching = false;
    setState(() => _view = _EntitiesView.search);
  }

  void _goToDetail(Entity entity) {
    setState(() {
      _view = _EntitiesView.detail;
      _selectedEntity = entity;
    });
  }

  Future<void> _doCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final lat = _location?.latitude ?? 33.6938;
    final lon = _location?.longitude ?? -117.9166;

    setState(() => _creating = true);
    try {
      final result = await widget.context.entities.publishEntity(
        PublishEntityRequest(
          name: name,
          lat: lat,
          lon: lon,
          disposition: _disposition,
        ),
      );
      debugPrint(
          '[EntityTaskManager] Published entity: ${result.entityId} "${result.displayName}"');
      if (mounted) {
        setState(
            () => _statusMessage = 'Created entity: ${result.displayName}');
        _goToList();
      }
    } catch (e) {
      debugPrint('[EntityTaskManager] Publish error: $e');
      if (mounted) {
        setState(() {
          _creating = false;
          _statusMessage = 'Create failed: $e';
        });
      }
    }
  }

  Future<void> _doSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      final found = await widget.context.entities.searchEntities(query);
      if (mounted) {
        setState(() {
          _entities = found;
          _statusMessage = 'Found ${found.length} matching entities';
          _searching = false;
        });
        _goToList();
      }
    } catch (e) {
      debugPrint('[EntityTaskManager] Search error: $e');
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickLocation() async {
    final loc = await widget.context.map.pickLocation();
    if (loc != null && mounted) setState(() => _location = loc);
  }

  Color _dispositionColor(Disposition d) {
    const c = LatticeColorScheme.dark;
    return switch (d) {
      Disposition.friendly => c.entityFriendly,
      Disposition.hostile => c.entityHostile,
      Disposition.neutral => c.success,
      Disposition.suspicious => const Color(0xFFFFEB3B), // domain: suspicious yellow
      Disposition.unknown => c.textSecondary,
    };
  }

  IconData _dispositionIcon(Disposition d) {
    return switch (d) {
      Disposition.friendly => Icons.shield,
      Disposition.hostile => Icons.warning,
      Disposition.neutral => Icons.circle_outlined,
      Disposition.suspicious => Icons.help_outline,
      Disposition.unknown => Icons.question_mark,
    };
  }

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      _EntitiesView.list => _buildListView(),
      _EntitiesView.create => _buildCreateView(),
      _EntitiesView.detail => _buildDetailView(),
      _EntitiesView.search => _buildSearchView(),
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
                  onPressed: _goToSearch,
                  icon: Icon(Icons.search,
                      size: 20, color: LatticeStyle.textSecondary),
                  style: IconButton.styleFrom(
                    backgroundColor: LatticeStyle.surface,
                    side: BorderSide(color: LatticeStyle.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
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
              : _entities.isEmpty
                  ? Center(
                      child: Text('No entities',
                          style: TextStyle(
                              color: LatticeStyle.textMuted, fontSize: 13)))
                  : ClipRect(
                      child: ListView.separated(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _entities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (ctx, i) =>
                            _buildEntityTile(_entities[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEntityTile(Entity entity) {
    return GestureDetector(
      onTap: () => _goToDetail(entity),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: LatticeStyle.surface,
          border: Border.all(color: LatticeStyle.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(_dispositionIcon(entity.disposition),
                size: 18, color: _dispositionColor(entity.disposition)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entity.name,
                      style: TextStyle(
                          color: LatticeStyle.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '${entity.disposition.name.toUpperCase()} \u2022 ${entity.lat.toStringAsFixed(4)}, ${entity.lon.toStringAsFixed(4)}',
                    style: TextStyle(
                        color: LatticeStyle.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 16, color: LatticeStyle.textMuted),
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
        _inlineHeader('Create Entity', onBack: _goToList),
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: TextStyle(
                        color: LatticeStyle.textPrimary, fontSize: 13),
                    decoration: LatticeStyle.inputDecoration('Entity name'),
                  ),
                  const SizedBox(height: 12),
                  Text('DISPOSITION',
                      style: TextStyle(
                          color: LatticeStyle.sectionLabel,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: Disposition.values.map((d) {
                      final selected = d == _disposition;
                      return GestureDetector(
                        onTap: () => setState(() => _disposition = d),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? context.lattice.colors.accent.withValues(alpha: 0.15)
                                : LatticeStyle.background,
                            border: Border.all(
                              color: selected
                                  ? context.lattice.colors.accent
                                  : LatticeStyle.border,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              d.name.toUpperCase(),
                              style: TextStyle(
                                color: selected
                                    ? context.lattice.colors.accent
                                    : LatticeStyle.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickLocation,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: LatticeStyle.surface,
                        border: Border.all(color: LatticeStyle.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: LatticeStyle.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _location != null
                                  ? '${_location!.latitude.toStringAsFixed(6)}, ${_location!.longitude.toStringAsFixed(6)}'
                                  : 'Pick location (default: HQ)',
                              style: TextStyle(
                                color: _location != null
                                    ? LatticeStyle.textPrimary
                                    : LatticeStyle.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
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
    final entity = _selectedEntity;
    if (entity == null) return const SizedBox.shrink();

    return Column(
      children: [
        _inlineHeader('Entity Detail', onBack: _goToList),
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _dispositionColor(entity.disposition),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entity.name,
                            style: TextStyle(
                                color: LatticeStyle.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailRow('ID', entity.id),
                  _detailRow(
                      'Disposition', entity.disposition.name.toUpperCase()),
                  _detailRow('Position',
                      '${entity.lat.toStringAsFixed(6)}, ${entity.lon.toStringAsFixed(6)}'),
                  _detailRow('Shape', entity.shapeType.name),
                  if (entity.extra != null && entity.extra!.isNotEmpty)
                    _detailRow(
                        'Extra',
                        const JsonEncoder.withIndent('  ')
                            .convert(entity.extra)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        await widget.context.map
                            .flyTo(LatLng(entity.lat, entity.lon), zoom: 15);
                      },
                      style: LatticeStyle.primaryButtonFrom(context.lattice.colors),
                      child: Text('Fly to Location',
                          style: TextStyle(
                              color: context.lattice.colors.onAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
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
  // Search view (inline)
  // ---------------------------------------------------------------------------

  Widget _buildSearchView() {
    return Column(
      children: [
        _inlineHeader('Search Entities', onBack: _goToList),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(
                      color: LatticeStyle.textPrimary, fontSize: 13),
                  decoration: LatticeStyle.inputDecoration('Search by name...'),
                  onSubmitted: (_) => _doSearch(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _searching ? null : _doSearch,
                  style: LatticeStyle.primaryButtonFrom(context.lattice.colors),
                  child: _searching
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                                      strokeWidth: 2, color: context.lattice.colors.onAccent))
                      : Text('Search',
                          style: TextStyle(
                              color: context.lattice.colors.onAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
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
