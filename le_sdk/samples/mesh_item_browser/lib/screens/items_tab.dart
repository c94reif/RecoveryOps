import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

import '../widgets/style.dart';

enum _ItemsView { typeList, itemList, itemDetail, createItem, editItem }

/// Items tab — browse discovered data types, CRUD typed items.
class ItemsTab extends StatefulWidget {
  final ExtensionContext context;

  const ItemsTab({super.key, required this.context});

  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<ItemsTab> {
  _ItemsView _view = _ItemsView.typeList;

  // Type list state
  List<MeshDataType> _dataTypes = [];
  bool _typesLoading = false;
  String? _typesError;

  // Selected type + item list state
  MeshDataTypePath? _selectedType;
  List<MeshItem> _items = [];
  bool _itemsLoading = false;
  String? _itemsError;

  // Selected item for detail
  MeshItem? _selectedItem;

  // Create / edit form state
  final _jsonController = TextEditingController();
  final _ttlController = TextEditingController();
  String? _formError;
  bool _formSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDataTypes();
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _ttlController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data operations
  // ---------------------------------------------------------------------------

  Future<void> _loadDataTypes() async {
    setState(() {
      _typesLoading = true;
      _typesError = null;
    });
    try {
      final types = await widget.context.meshItemStore.items.listDataTypes();
      if (mounted) setState(() => _dataTypes = types);
    } catch (e) {
      if (mounted) setState(() => _typesError = e.toString());
    } finally {
      if (mounted) setState(() => _typesLoading = false);
    }
  }

  Future<void> _loadItems(MeshDataTypePath type) async {
    setState(() {
      _itemsLoading = true;
      _itemsError = null;
      _items = [];
    });
    try {
      final items = await widget.context.meshItemStore.items.listItems(type);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _itemsError = e.toString());
    } finally {
      if (mounted) setState(() => _itemsLoading = false);
    }
  }

  void _openTypeDetail(MeshDataTypePath type) {
    setState(() {
      _selectedType = type;
      _view = _ItemsView.itemList;
    });
    _loadItems(type);
  }

  void _openItemDetail(MeshItem item) {
    setState(() {
      _selectedItem = item;
      _view = _ItemsView.itemDetail;
    });
  }

  void _openCreateForm() {
    _jsonController.text = '{\n  \n}';
    _ttlController.clear();
    setState(() {
      _formError = null;
      _formSubmitting = false;
      _view = _ItemsView.createItem;
    });
  }

  void _openEditForm(MeshItem item) {
    _jsonController.text =
        const JsonEncoder.withIndent('  ').convert(item.data);
    _ttlController.clear();
    setState(() {
      _selectedItem = item;
      _formError = null;
      _formSubmitting = false;
      _view = _ItemsView.editItem;
    });
  }

  void _goToTypeList() {
    setState(() {
      _view = _ItemsView.typeList;
      _selectedType = null;
      _selectedItem = null;
      _items = [];
    });
  }

  void _goToItemList() {
    setState(() {
      _view = _ItemsView.itemList;
      _selectedItem = null;
    });
  }

  Future<void> _doCreate() async {
    final type = _selectedType;
    if (type == null) return;

    Map<String, Object?> data;
    try {
      data = (jsonDecode(_jsonController.text) as Map).cast<String, Object?>();
    } on FormatException catch (e) {
      setState(() => _formError = 'Invalid JSON: ${e.message}');
      return;
    }

    Duration? ttl;
    final ttlText = _ttlController.text.trim();
    if (ttlText.isNotEmpty) {
      final secs = int.tryParse(ttlText);
      if (secs == null || secs <= 0) {
        setState(() => _formError = 'TTL must be a positive integer (seconds)');
        return;
      }
      ttl = Duration(seconds: secs);
    }

    setState(() {
      _formSubmitting = true;
      _formError = null;
    });
    try {
      await widget.context.meshItemStore.items.createItem(type, data, ttl: ttl);
      if (mounted) {
        _goToItemList();
        await _loadItems(type);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _formError = e.toString();
          _formSubmitting = false;
        });
      }
    }
  }

  Future<void> _doUpdate() async {
    final item = _selectedItem;
    if (item == null) return;

    Map<String, Object?> data;
    try {
      data = (jsonDecode(_jsonController.text) as Map).cast<String, Object?>();
    } on FormatException catch (e) {
      setState(() => _formError = 'Invalid JSON: ${e.message}');
      return;
    }

    Duration? ttl;
    final ttlText = _ttlController.text.trim();
    if (ttlText.isNotEmpty) {
      final secs = int.tryParse(ttlText);
      if (secs == null || secs <= 0) {
        setState(() => _formError = 'TTL must be a positive integer (seconds)');
        return;
      }
      ttl = Duration(seconds: secs);
    }

    setState(() {
      _formSubmitting = true;
      _formError = null;
    });
    try {
      await widget.context.meshItemStore.items.updateItem(item.path, data, ttl: ttl);
      if (mounted) {
        _goToItemList();
        await _loadItems(item.path.type);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _formError = e.toString();
          _formSubmitting = false;
        });
      }
    }
  }

  Future<void> _doDelete(MeshItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LatticeStyle.surface,
        title: Text(
          'Delete item?',
          style: TextStyle(color: LatticeStyle.textPrimary, fontSize: 14),
        ),
        content: Text(
          'ID: ${item.path.id}',
          style: TextStyle(color: LatticeStyle.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: LatticeStyle.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text('Delete', style: TextStyle(color: LatticeStyle.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.context.meshItemStore.items.deleteItem(item.path);
      if (mounted) {
        _goToItemList();
        await _loadItems(item.path.type);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e',
                style: const TextStyle(fontSize: 12)),
            backgroundColor: LatticeStyle.error,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      _ItemsView.typeList => _buildTypeListView(),
      _ItemsView.itemList => _buildItemListView(),
      _ItemsView.itemDetail => _buildItemDetailView(),
      _ItemsView.createItem => _buildItemForm(editMode: false),
      _ItemsView.editItem => _buildItemForm(editMode: true),
    };
  }

  // ---------------------------------------------------------------------------
  // Type list view
  // ---------------------------------------------------------------------------

  Widget _buildTypeListView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items',
                      style: TextStyle(
                        color: LatticeStyle.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Discovered data types',
                      style: TextStyle(
                          color: LatticeStyle.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                width: 48,
                child: IconButton(
                  onPressed: _loadDataTypes,
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
        const SizedBox(height: 8),
        Expanded(
          child: _typesLoading
              ? Center(
                  child: CircularProgressIndicator(
                      color: context.lattice.colors.accent))
              : _typesError != null
                  ? _buildErrorCard(_typesError!, onRetry: _loadDataTypes)
                  : _dataTypes.isEmpty
                      ? Center(
                          child: Text(
                            'No data types discovered',
                            style: TextStyle(
                                color: LatticeStyle.textMuted, fontSize: 13),
                          ),
                        )
                      : ClipRect(
                          child: ListView.separated(
                            physics: const ClampingScrollPhysics(),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _dataTypes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (ctx, i) =>
                                _buildDataTypeItem(_dataTypes[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildDataTypeItem(MeshDataType dt) {
    final path = dt.path;
    final pathStr =
        '${path.namespace}/${path.domain}/${path.dataType}/${path.version}';
    return GestureDetector(
      onTap: () => _openTypeDetail(path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: LatticeStyle.surface,
          border: Border.all(color: LatticeStyle.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.schema_outlined,
                size: 18, color: LatticeStyle.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pathStr,
                          style: TextStyle(
                            color: LatticeStyle.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (dt.isDeprecated)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '(deprecated)',
                            style: TextStyle(
                                color: LatticeStyle.textMuted, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    'schema: ${dt.schema.length} bytes',
                    style: TextStyle(
                        color: LatticeStyle.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: LatticeStyle.textMuted),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Item list view (for a selected type)
  // ---------------------------------------------------------------------------

  Widget _buildItemListView() {
    final type = _selectedType;
    if (type == null) return const SizedBox.shrink();
    final pathStr =
        '${type.namespace}/${type.domain}/${type.dataType}/${type.version}';

    return Column(
      children: [
        _inlineHeader(
          pathStr,
          onBack: _goToTypeList,
          trailing: SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              onPressed: _openCreateForm,
              icon: Icon(Icons.add,
                  size: 20, color: context.lattice.colors.accent),
              style: IconButton.styleFrom(
                backgroundColor:
                    context.lattice.colors.accent.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
        Expanded(
          child: _itemsLoading
              ? Center(
                  child: CircularProgressIndicator(
                      color: context.lattice.colors.accent))
              : _itemsError != null
                  ? _buildErrorCard(_itemsError!,
                      onRetry: () => _loadItems(type))
                  : _items.isEmpty
                      ? Center(
                          child: Text(
                            'No items',
                            style: TextStyle(
                                color: LatticeStyle.textMuted, fontSize: 13),
                          ),
                        )
                      : ClipRect(
                          child: ListView.separated(
                            physics: const ClampingScrollPhysics(),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (ctx, i) =>
                                _buildMeshDataItem(_items[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildMeshDataItem(MeshItem item) {
    final preview = _jsonPreview(item.data, maxLen: 80);
    final createdStr = _formatTime(item.createdAt);
    return GestureDetector(
      onTap: () => _openItemDetail(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: LatticeStyle.surface,
          border: Border.all(color: LatticeStyle.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.path.id,
                    style: TextStyle(
                      color: LatticeStyle.textPrimary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'created $createdStr',
                    style: TextStyle(
                        color: LatticeStyle.textMuted, fontSize: 10),
                  ),
                  if (item.expiryTime != null)
                    Text(
                      'expires ${_formatTime(item.expiryTime!)}',
                      style: TextStyle(
                          color: LatticeStyle.textMuted, fontSize: 10),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    style: TextStyle(
                      color: LatticeStyle.textSecondary,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => _doDelete(item),
                icon:
                    Icon(Icons.delete_outline, size: 18, color: LatticeStyle.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Item detail view
  // ---------------------------------------------------------------------------

  Widget _buildItemDetailView() {
    final item = _selectedItem;
    if (item == null) return const SizedBox.shrink();

    final type = item.path.type;
    final pathStr =
        '${type.namespace}/${type.domain}/${type.dataType}/${type.version}';

    return Column(
      children: [
        _inlineHeader('Item Detail', onBack: _goToItemList),
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('TYPE'),
                  const SizedBox(height: 4),
                  Text(
                    pathStr,
                    style: TextStyle(
                      color: LatticeStyle.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailRow('ID', item.path.id),
                  _detailRow('Created', _formatTime(item.createdAt)),
                  if (item.expiryTime != null)
                    _detailRow('Expires', _formatTime(item.expiryTime!)),
                  const SizedBox(height: 12),
                  _sectionLabel('DATA'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: LatticeStyle.background,
                      border: Border.all(color: LatticeStyle.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      const JsonEncoder.withIndent('  ').convert(item.data),
                      style: TextStyle(
                        color: LatticeStyle.textPrimary,
                        fontSize: 11,
                        fontFamily: 'monospace',
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
                            onPressed: () => _openEditForm(item),
                            style: LatticeStyle.primaryButtonFrom(
                                context.lattice.colors),
                            child: Text(
                              'Edit',
                              style: TextStyle(
                                color: context.lattice.colors.onAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => _doDelete(item),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LatticeStyle.error
                                  .withValues(alpha: 0.15),
                              foregroundColor: LatticeStyle.error,
                              side: BorderSide(color: LatticeStyle.error),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
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
  // Create / edit item form
  // ---------------------------------------------------------------------------

  Widget _buildItemForm({required bool editMode}) {
    return Column(
      children: [
        _inlineHeader(
          editMode ? 'Edit Item' : 'Create Item',
          onBack: editMode ? _goToItemDetail : _goToItemList,
        ),
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('JSON DATA'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _jsonController,
                    autofocus: true,
                    maxLines: 10,
                    minLines: 6,
                    style: TextStyle(
                      color: LatticeStyle.textPrimary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    decoration: LatticeStyle.inputDecoration('{ "key": "value" }'),
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel('TTL (SECONDS, OPTIONAL)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _ttlController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                        color: LatticeStyle.textPrimary, fontSize: 13),
                    decoration: LatticeStyle.inputDecoration('e.g. 86400'),
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: LatticeStyle.error.withValues(alpha: 0.1),
                        border: Border.all(color: LatticeStyle.error),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formError!,
                        style: TextStyle(
                            color: LatticeStyle.error, fontSize: 11),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: editMode ? _goToItemDetail : _goToItemList,
                            style: LatticeStyle.secondaryButtonFrom(
                                context.lattice.colors),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: LatticeStyle.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _formSubmitting
                                ? null
                                : editMode
                                    ? _doUpdate
                                    : _doCreate,
                            style: LatticeStyle.primaryButtonFrom(
                                context.lattice.colors),
                            child: _formSubmitting
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.lattice.colors.onAccent,
                                    ),
                                  )
                                : Text(
                                    editMode ? 'Save' : 'Create',
                                    style: TextStyle(
                                      color: context.lattice.colors.onAccent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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

  void _goToItemDetail() {
    setState(() => _view = _ItemsView.itemDetail);
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Widget _inlineHeader(
    String title, {
    required VoidCallback onBack,
    Widget? trailing,
  }) {
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
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: LatticeStyle.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing,
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
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: LatticeStyle.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: LatticeStyle.textPrimary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: LatticeStyle.sectionLabel,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildErrorCard(String error, {required VoidCallback onRetry}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LatticeStyle.error.withValues(alpha: 0.1),
          border: Border.all(color: LatticeStyle.error.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: LatticeStyle.error),
                const SizedBox(width: 6),
                Text(
                  'Error',
                  style: TextStyle(
                    color: LatticeStyle.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              error,
              style: TextStyle(color: LatticeStyle.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LatticeStyle.surface,
                  foregroundColor: LatticeStyle.textSecondary,
                  side: BorderSide(color: LatticeStyle.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _jsonPreview(Map<String, Object?> data, {required int maxLen}) {
    final raw = jsonEncode(data);
    if (raw.length <= maxLen) return raw;
    return '${raw.substring(0, maxLen)}…';
  }

  String _formatTime(DateTime t) {
    final local = t.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final d = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    return '$d $h:$m';
  }
}
