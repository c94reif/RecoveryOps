import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart';
import 'package:le_sdk/le_sdk.dart';

/// Lists objects from the Lattice CDN with prefix filtering, metadata display,
/// download, and delete actions.
class BrowseTab extends StatefulWidget {
  const BrowseTab({super.key, required this.context});
  final ExtensionContext context;

  @override
  State<BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<BrowseTab> {
  final _prefixController = TextEditingController();
  List<ObjectMetadata>? _items;
  bool _loading = false;
  String? _error;
  ObjectMetadata? _selected;
  Uint8List? _downloadedBytes;

  @override
  void initState() {
    super.initState();
    _loadObjects();
  }

  @override
  void dispose() {
    _prefixController.dispose();
    super.dispose();
  }

  Future<void> _loadObjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.context.objects.list(
        prefix: _prefixController.text.isEmpty ? null : _prefixController.text,
      );
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _downloadObject(ObjectMetadata meta) async {
    setState(() => _loading = true);
    try {
      final bytes = await widget.context.objects.download(meta.path);
      if (bytes == null) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Object not found')));
        }
        return;
      }
      setState(() {
        _downloadedBytes = bytes;
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${bytes.length} bytes')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteObject(ObjectMetadata meta) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: ctx.lattice.colors.surface,
            title: const Text('Delete Object'),
            content: Text('Delete "${meta.path}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: ctx.lattice.colors.error),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await widget.context.objects.delete(meta.path);
      setState(() => _selected = null);
      _loadObjects();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Object deleted')));
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;

    if (_selected != null) {
      return _buildDetailView(colors);
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _prefixController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Filter by prefix...',
                    hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: colors.surface,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: colors.borderActive),
                    ),
                  ),
                  onSubmitted: (_) => _loadObjects(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.search, color: colors.accent),
                onPressed: () => _loadObjects(),
              ),
            ],
          ),
        ),
        // Content
        Expanded(child: _buildList(colors)),
      ],
    );
  }

  Widget _buildList(LatticeColorScheme colors) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 32),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colors.error, fontSize: 12)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadObjects,
              child: Text('Retry', style: TextStyle(color: colors.accent)),
            ),
          ],
        ),
      );
    }
    if (_items == null || _items!.isEmpty) {
      return Center(
        child: Text(
          'No objects found',
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _items!.length,
      itemBuilder: (ctx, i) {
        final item = _items![i];
        return GestureDetector(
          onTap: () => setState(() => _selected = item),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.borderActive),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file,
                  size: 16,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.path,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${_formatBytes(item.sizeBytes)} \u2022 ${_formatTime(item.lastUpdatedAt)}',
                        style: TextStyle(color: colors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailView(LatticeColorScheme colors) {
    final meta = _selected!;
    return Column(
      children: [
        // Header
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: colors.surface,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: colors.textPrimary,
                  size: 20,
                ),
                onPressed:
                    () => setState(() {
                      _selected = null;
                      _downloadedBytes = null;
                    }),
              ),
              Expanded(
                child: Text(
                  meta.path,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Metadata
        Expanded(
          child:
              _loading
                  ? Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  )
                  : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _metaRow(colors, 'Path', meta.path),
                        _metaRow(colors, 'Size', _formatBytes(meta.sizeBytes)),
                        _metaRow(
                          colors,
                          'Updated',
                          _formatTime(meta.lastUpdatedAt),
                        ),
                        if (meta.expiryTime != null)
                          _metaRow(
                            colors,
                            'Expires',
                            _formatTime(meta.expiryTime!),
                          ),
                        if (meta.checksum != null)
                          _metaRow(
                            colors,
                            'Checksum',
                            meta.checksum!.substring(0, 16) + '...',
                          ),
                        const SizedBox(height: 16),
                        if (_downloadedBytes != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _downloadedBytes!.length < 2000
                                  ? String.fromCharCodes(_downloadedBytes!)
                                  : '${_downloadedBytes!.length} bytes (too large to preview)',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 10,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _downloadObject(meta),
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('Download'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _deleteObject(meta),
                                icon: const Icon(Icons.delete, size: 16),
                                label: const Text('Delete'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _metaRow(LatticeColorScheme colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: colors.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTime(DateTime dt) {
    if (dt.year == 0) return 'unknown';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
