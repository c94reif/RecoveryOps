import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:le_sdk/le_sdk.dart';

import '../widgets/style.dart';

enum _StreamsView { typeList, liveTail, publish }

/// Streams tab — browse discovered stream data types, live-tail, and publish.
class StreamsTab extends StatefulWidget {
  final ExtensionContext context;

  const StreamsTab({super.key, required this.context});

  @override
  State<StreamsTab> createState() => _StreamsTabState();
}

class _StreamsTabState extends State<StreamsTab> {
  _StreamsView _view = _StreamsView.typeList;

  // Type list state
  List<MeshDataType> _streamTypes = [];
  bool _typesLoading = false;
  String? _typesError;

  // Selected stream type + live tail state
  MeshDataTypePath? _selectedType;
  final List<MeshStreamMessage> _messages = [];
  StreamSubscription<MeshStreamMessage>? _sub;
  bool _subscribing = false;
  String? _subError;

  // Publish form state
  final _publishJsonController = TextEditingController();
  String? _publishError;
  bool _publishing = false;

  static const _maxMessages = 200;

  @override
  void initState() {
    super.initState();
    _loadStreamTypes();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _publishJsonController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data operations
  // ---------------------------------------------------------------------------

  Future<void> _loadStreamTypes() async {
    setState(() {
      _typesLoading = true;
      _typesError = null;
    });
    try {
      final types = await widget.context.meshItemStore.streams.listStreamDataTypes();
      if (mounted) setState(() => _streamTypes = types);
    } catch (e) {
      if (mounted) setState(() => _typesError = e.toString());
    } finally {
      if (mounted) setState(() => _typesLoading = false);
    }
  }

  Future<void> _openLiveTail(MeshDataTypePath type) async {
    await _sub?.cancel();
    _sub = null;
    setState(() {
      _selectedType = type;
      _messages.clear();
      _subError = null;
      _subscribing = true;
      _view = _StreamsView.liveTail;
    });

    try {
      final stream = widget.context.meshItemStore.streams.subscribe(type);
      _sub = stream.listen(
        (msg) {
          if (!mounted) return;
          setState(() {
            _messages.insert(0, msg);
            if (_messages.length > _maxMessages) {
              _messages.removeRange(_maxMessages, _messages.length);
            }
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() => _subError = e.toString());
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _subError = null);
        },
      );
      if (mounted) setState(() => _subscribing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _subError = e.toString();
          _subscribing = false;
        });
      }
    }
  }

  void _goToTypeList() {
    _sub?.cancel();
    _sub = null;
    setState(() {
      _view = _StreamsView.typeList;
      _selectedType = null;
      _messages.clear();
      _subError = null;
    });
  }

  void _goToLiveTail() {
    setState(() {
      _view = _StreamsView.liveTail;
      _publishError = null;
    });
  }

  void _openPublishForm() {
    _publishJsonController.text = '{\n  \n}';
    setState(() {
      _publishError = null;
      _publishing = false;
      _view = _StreamsView.publish;
    });
  }

  Future<void> _doPublish() async {
    final type = _selectedType;
    if (type == null) return;

    Map<String, Object?> data;
    try {
      data = (jsonDecode(_publishJsonController.text) as Map)
          .cast<String, Object?>();
    } on FormatException catch (e) {
      setState(() => _publishError = 'Invalid JSON: ${e.message}');
      return;
    }

    setState(() {
      _publishing = true;
      _publishError = null;
    });
    try {
      final result =
          await widget.context.meshItemStore.streams.publish(type, [data]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Published ${result.succeeded}/${result.total} messages',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: result.failed == 0
                ? LatticeStyle.success
                : LatticeStyle.error,
            duration: const Duration(seconds: 3),
          ),
        );
        _goToLiveTail();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _publishError = e.toString();
          _publishing = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      _StreamsView.typeList => _buildTypeListView(),
      _StreamsView.liveTail => _buildLiveTailView(),
      _StreamsView.publish => _buildPublishForm(),
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
                      'Streams',
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
                  onPressed: _loadStreamTypes,
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
                  ? _buildErrorCard(_typesError!, onRetry: _loadStreamTypes)
                  : _streamTypes.isEmpty
                      ? Center(
                          child: Text(
                            'No stream types discovered',
                            style: TextStyle(
                                color: LatticeStyle.textMuted, fontSize: 13),
                          ),
                        )
                      : ClipRect(
                          child: ListView.separated(
                            physics: const ClampingScrollPhysics(),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _streamTypes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (ctx, i) =>
                                _buildStreamTypeItem(_streamTypes[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildStreamTypeItem(MeshDataType dt) {
    final path = dt.path;
    final pathStr =
        '${path.namespace}/${path.domain}/${path.dataType}/${path.version}';
    return GestureDetector(
      onTap: () => _openLiveTail(path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: LatticeStyle.surface,
          border: Border.all(color: LatticeStyle.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.stream, size: 18, color: LatticeStyle.textSecondary),
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
  // Live tail view
  // ---------------------------------------------------------------------------

  Widget _buildLiveTailView() {
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
              onPressed: _openPublishForm,
              icon: Icon(Icons.send,
                  size: 18, color: context.lattice.colors.accent),
              style: IconButton.styleFrom(
                backgroundColor: context.lattice.colors.accent
                    .withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
        if (_subError != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: LatticeStyle.error.withValues(alpha: 0.1),
              border: Border.all(
                  color: LatticeStyle.error.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: LatticeStyle.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _subError!,
                    style: TextStyle(color: LatticeStyle.error, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _subscribing
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: context.lattice.colors.accent),
                      const SizedBox(height: 8),
                      Text(
                        'Opening stream…',
                        style: TextStyle(
                            color: LatticeStyle.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Waiting for messages…',
                        style: TextStyle(
                            color: LatticeStyle.textMuted, fontSize: 13),
                      ),
                    )
                  : ClipRect(
                      child: ListView.separated(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _messages.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 4),
                        itemBuilder: (ctx, i) =>
                            _buildMessageItem(_messages[i]),
                      ),
                    ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _subError != null
                      ? LatticeStyle.error
                      : LatticeStyle.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _subError != null
                    ? 'Error'
                    : _subscribing
                        ? 'Connecting…'
                        : '${_messages.length} messages (newest first, cap 200)',
                style:
                    TextStyle(color: LatticeStyle.textMuted, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageItem(MeshStreamMessage msg) {
    final preview = _jsonPreview(msg.data, maxLen: 80);
    final timeStr = _formatTime(msg.receivedAt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: LatticeStyle.surface,
        border: Border.all(color: LatticeStyle.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeStr,
            style: TextStyle(color: LatticeStyle.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            preview,
            style: TextStyle(
              color: LatticeStyle.textSecondary,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Publish form
  // ---------------------------------------------------------------------------

  Widget _buildPublishForm() {
    return Column(
      children: [
        _inlineHeader('Publish Message', onBack: _goToLiveTail),
        Expanded(
          child: ClipRect(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('JSON PAYLOAD'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _publishJsonController,
                    autofocus: true,
                    maxLines: 10,
                    minLines: 6,
                    style: TextStyle(
                      color: LatticeStyle.textPrimary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    decoration:
                        LatticeStyle.inputDecoration('{ "key": "value" }'),
                  ),
                  if (_publishError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: LatticeStyle.error.withValues(alpha: 0.1),
                        border: Border.all(color: LatticeStyle.error),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _publishError!,
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
                            onPressed: _goToLiveTail,
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
                            onPressed: _publishing ? null : _doPublish,
                            style: LatticeStyle.primaryButtonFrom(
                                context.lattice.colors),
                            child: _publishing
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          context.lattice.colors.onAccent,
                                    ),
                                  )
                                : Text(
                                    'Publish',
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
              style: TextStyle(
                  color: LatticeStyle.textSecondary, fontSize: 11),
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
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
